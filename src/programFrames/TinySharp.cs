//code from https://blog.washi.dev/posts/tinysharp/
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Linq;
using AsmResolver;
using AsmResolver.DotNet;
using AsmResolver.DotNet.Builder.Metadata;
using AsmResolver.DotNet.Code.Cil;
using AsmResolver.DotNet.Signatures;
using AsmResolver.IO;
using AsmResolver.PE;
using AsmResolver.PE.Builder;
using AsmResolver.PE.Code;
using AsmResolver.PE.DotNet;
using AsmResolver.PE.DotNet.Cil;
using AsmResolver.PE.DotNet.Metadata;
using AsmResolver.PE.DotNet.Metadata.Tables;
using AsmResolver.PE.Win32Resources;
using AsmResolver.PE.Win32Resources.Icon;
using AsmResolver.PE.Win32Resources.Version;
using AsmResolver.PE.File;

namespace TinySharp {
	public class Program {
		public static Program Compile(
			string targetRuntime, string architecture = "x64",
			string outputValue = "Hello World!", int ExitCode = 0, bool hasOutput = true,
			bool useMessageBox = false
		) {
			if (useMessageBox && hasOutput)
				return CompileMessageBox(targetRuntime, architecture, outputValue, ExitCode);
			string baseFunction = "7";
			bool allASCIIoutput = outputValue.All(c => c >= 0 && c <= 127);
			var module = new ModuleDefinition("Dummy");

			// Segment containing our string to print.
			DataSegment segment = new DataSegment((allASCIIoutput?Encoding.ASCII:Encoding.Unicode).GetBytes(outputValue+'\0'));

			var PEKind = OptionalHeaderMagic.PE64;
			var ArchType = MachineType.Amd64;
			if (architecture != "x64") {
				PEKind = OptionalHeaderMagic.PE32;
				ArchType = MachineType.I386;
			}

			// Initialize a new PE image and set up some default values.
			var image = new PEImage {
				ImageBase = 0x00000000004e0000,
				PEKind = PEKind,
				MachineType = ArchType
			};

			// Ensure PE is loaded at the provided image base.
			image.DllCharacteristics &= ~DllCharacteristics.DynamicBase;

			// Create new metadata streams.
			var tablesStream = new TablesStream();
			var blobStreamBuffer = new BlobStreamBuffer();
			var stringsStreamBuffer = new StringsStreamBuffer();

			// Add empty module row.
			tablesStream.GetTable<ModuleDefinitionRow>().Add(new ModuleDefinitionRow());

			// Add container type def for our main function (<Module>).
			tablesStream.GetTable<TypeDefinitionRow>().Add(new TypeDefinitionRow(
				0, 0, 0, 0, 1, 1
			));

			var methodTable = tablesStream.GetTable<MethodDefinitionRow>();

			// Add puts method.
			if (hasOutput)
				if(allASCIIoutput) {
					baseFunction = "puts";
					methodTable.Add(new MethodDefinitionRow(
						SegmentReference.Null,
						MethodImplAttributes.PreserveSig,
						MethodAttributes.Static | MethodAttributes.PInvokeImpl,
						stringsStreamBuffer.GetStringIndex("puts"),
						blobStreamBuffer.GetBlobIndex(
							module,
							new DummyProvider(),
							MethodSignature.CreateStatic(
								module.CorLibTypeFactory.Void,
								new[] { module.CorLibTypeFactory.IntPtr }),
							ThrowErrorListener.Instance),
						1
					));
				}
				else {
					baseFunction = "WriteConsoleW";
					methodTable.Add(new MethodDefinitionRow(
						SegmentReference.Null,
						MethodImplAttributes.PreserveSig,
						MethodAttributes.Static | MethodAttributes.PInvokeImpl,
						stringsStreamBuffer.GetStringIndex("GetStdHandle"),
						blobStreamBuffer.GetBlobIndex(
							module,
							new DummyProvider(),
							MethodSignature.CreateStatic(
								module.CorLibTypeFactory.IntPtr,
								new[] { module.CorLibTypeFactory.Int32 }),
							ThrowErrorListener.Instance),
						1
					));
					methodTable.Add(new MethodDefinitionRow(
						SegmentReference.Null,
						MethodImplAttributes.PreserveSig,
						MethodAttributes.Static | MethodAttributes.PInvokeImpl,
						stringsStreamBuffer.GetStringIndex("WriteConsoleW"),
						blobStreamBuffer.GetBlobIndex(
							module,
							new DummyProvider(),
							MethodSignature.CreateStatic(
								module.CorLibTypeFactory.Void,
								new[]
								{
									module.CorLibTypeFactory.IntPtr,
									module.CorLibTypeFactory.IntPtr,
									module.CorLibTypeFactory.Int32,
									module.CorLibTypeFactory.IntPtr,
									module.CorLibTypeFactory.IntPtr
								}),
							ThrowErrorListener.Instance),
						1
					));
				}

			// Add main method calling puts.
			using(var codeStream = new MemoryStream()) {
				var assembler = new CilAssembler(new BinaryStreamWriter(codeStream), new CilOperandBuilder(new OriginalMetadataTokenProvider(null), ThrowErrorListener.Instance));
				uint patchIndex = 0;
				if (hasOutput) {
					if(allASCIIoutput) {
						patchIndex = 2;
						assembler.WriteInstruction(new CilInstruction(CilOpCodes.Ldc_I4, 5112224));
						assembler.WriteInstruction(new CilInstruction(CilOpCodes.Call, new MetadataToken(TableIndex.Method, 1)));
					}
					else {
						patchIndex = 12;
						assembler.WriteInstruction(new CilInstruction(CilOpCodes.Ldc_I4, -11)); // STD_OUTPUT_HANDLE
						assembler.WriteInstruction(new CilInstruction(CilOpCodes.Call, new MetadataToken(TableIndex.Method, 1)));
						assembler.WriteInstruction(new CilInstruction(CilOpCodes.Ldc_I4, 5112224));
						assembler.WriteInstruction(new CilInstruction(CilOpCodes.Ldc_I4, outputValue.Length)); // size of string
						assembler.WriteInstruction(new CilInstruction(CilOpCodes.Ldc_I4, 0x00000000)); // reserve size outputed
						assembler.WriteInstruction(new CilInstruction(CilOpCodes.Ldc_I4, 0x00000000)); // reserved
						assembler.WriteInstruction(new CilInstruction(CilOpCodes.Call, new MetadataToken(TableIndex.Method, 2)));
					}
				}
				if (ExitCode != 0)
					assembler.WriteInstruction(new CilInstruction(CilOpCodes.Ldc_I4, ExitCode));
				assembler.WriteInstruction(new CilInstruction(CilOpCodes.Ret));

				var body = new CilRawTinyMethodBody(codeStream.ToArray()).AsPatchedSegment();
				if (hasOutput)
					body = body.Patch(patchIndex, AddressFixupType.Absolute32BitAddress, new Symbol(segment.ToReference()));

				var retype = module.CorLibTypeFactory.Void;
				if (ExitCode != 0)
					retype = module.CorLibTypeFactory.Int32;

				methodTable.Add(new MethodDefinitionRow(
					body.ToReference(),
					0,
					MethodAttributes.Static,
					0,
					blobStreamBuffer.GetBlobIndex(
						module,
						new DummyProvider(),
						MethodSignature.CreateStatic(retype),
						ThrowErrorListener.Instance),
					1
				));
			}

			if (hasOutput) {
				// Add urctbase module reference
				var baseLibrary = allASCIIoutput ? "ucrtbase" : "Kernel32";
				tablesStream.GetTable<ModuleReferenceRow>().Add(new ModuleReferenceRow(stringsStreamBuffer.GetStringIndex(baseLibrary)));

				// Add P/Invoke metadata to the puts method.
				if (allASCIIoutput)
					tablesStream.GetTable<ImplementationMapRow>().Add(new ImplementationMapRow(
						ImplementationMapAttributes.CallConvCdecl,
						tablesStream.GetIndexEncoder(CodedIndex.MemberForwarded).EncodeToken(new MetadataToken(TableIndex.Method, 1)),
						stringsStreamBuffer.GetStringIndex("puts"),
						1
					));
				else {
					tablesStream.GetTable<ImplementationMapRow>().Add(new ImplementationMapRow(
						ImplementationMapAttributes.CallConvCdecl,
						tablesStream.GetIndexEncoder(CodedIndex.MemberForwarded).EncodeToken(new MetadataToken(TableIndex.Method, 1)),
						stringsStreamBuffer.GetStringIndex("GetStdHandle"),
						1
					));
					tablesStream.GetTable<ImplementationMapRow>().Add(new ImplementationMapRow(
						ImplementationMapAttributes.CallConvCdecl,
						tablesStream.GetIndexEncoder(CodedIndex.MemberForwarded).EncodeToken(new MetadataToken(TableIndex.Method, 2)),
						stringsStreamBuffer.GetStringIndex("WriteConsoleW"),
						1
					));
				}
			}

			// Define assembly manifest.
			tablesStream.GetTable<AssemblyDefinitionRow>().Add(new AssemblyDefinitionRow(
				0,
				1, 0, 0, 0,
				0,
				0,
				stringsStreamBuffer.GetStringIndex(baseFunction), // The CLR does not allow for assemblies with a null name. Reuse the name "puts" to safe space.
				0
			));

			// Add all .NET metadata to the PE image.
			var metadataDirectory = new MetadataDirectory {
				VersionString = targetRuntime == "Framework2.0" ? "v2.0." : "v4.0."
			};
			metadataDirectory.Streams.Add(tablesStream);
			metadataDirectory.Streams.Add(blobStreamBuffer.CreateStream());
			metadataDirectory.Streams.Add(stringsStreamBuffer.CreateStream());

			image.DotNetDirectory = new DotNetDirectory {
				EntryPoint = new MetadataToken(TableIndex.Method, hasOutput?allASCIIoutput?2u:3u:1u),
				Metadata = metadataDirectory
			};
			if (architecture == "anycpu")
				image.DotNetDirectory.Flags &= ~DotNetDirectoryFlags.Bit32Required;

			var result = new Program();
			result.Image = image;

			// Put string to print in the padding data.
			if (hasOutput) result.OutSegment = segment;

			return result;
		}

		/// <summary>Build minimal PE that shows MessageBoxW(text, caption) then exits. Used for -noConsole const output.
		/// Caption is resolved at runtime: first tries Win32 version resource FileDescription (title), falls back to
		/// GetModuleFileNameW+PathFindFileNameW (filename), so both survive exe rename and honour -title.</summary>
		private static Program CompileMessageBox(string targetRuntime, string architecture, string outputValue, int ExitCode) {
			var module = new ModuleDefinition("Dummy");
			DataSegment textSegment = new DataSegment(Encoding.Unicode.GetBytes(outputValue + '\0'));
			// VerQueryValueW subBlock path — matches AsmResolver StringTable(language:0, codepage:0x4b0)
			DataSegment subBlockStr = new DataSegment(Encoding.Unicode.GetBytes("\\StringFileInfo\\000004b0\\FileDescription\0"));

			// Writable BSS segments (zero-initialised by OS loader, no file bytes)
			var pathBufSeg   = new VirtualSegment(null, 260 * 2u); // GetModuleFileNameW path buffer
			var viBufSeg     = new VirtualSegment(null, 4096u);    // GetFileVersionInfoW data buffer
			var pValueBufSeg = new VirtualSegment(null, 8u);       // VerQueryValueW output pointer (up to 8 bytes for x64)
			var lenBufSeg    = new VirtualSegment(null, 4u);       // VerQueryValueW output length (UINT)

			var PEKind = OptionalHeaderMagic.PE64;
			var ArchType = MachineType.Amd64;
			if (architecture != "x64") {
				PEKind = OptionalHeaderMagic.PE32;
				ArchType = MachineType.I386;
			}
			var image = new PEImage {
				ImageBase = 0x00000000004e0000,
				PEKind = PEKind,
				MachineType = ArchType
			};
			image.DllCharacteristics &= ~DllCharacteristics.DynamicBase;

			var tablesStream = new TablesStream();
			var blobStreamBuffer = new BlobStreamBuffer();
			var stringsStreamBuffer = new StringsStreamBuffer();
			tablesStream.GetTable<ModuleDefinitionRow>().Add(new ModuleDefinitionRow());
			tablesStream.GetTable<TypeDefinitionRow>().Add(new TypeDefinitionRow(0, 0, 0, 0, 1, 1));

			var methodTable = tablesStream.GetTable<MethodDefinitionRow>();
			// 1: MessageBoxW (user32)
			methodTable.Add(new MethodDefinitionRow(
				SegmentReference.Null, MethodImplAttributes.PreserveSig,
				MethodAttributes.Static | MethodAttributes.PInvokeImpl,
				stringsStreamBuffer.GetStringIndex("MessageBoxW"),
				blobStreamBuffer.GetBlobIndex(module, new DummyProvider(),
					MethodSignature.CreateStatic(module.CorLibTypeFactory.Void, new[] {
						module.CorLibTypeFactory.IntPtr, module.CorLibTypeFactory.IntPtr,
						module.CorLibTypeFactory.IntPtr, module.CorLibTypeFactory.UInt32
					}), ThrowErrorListener.Instance), 1));
			// 2: GetModuleFileNameW (kernel32): (hModule, lpFilename, nSize) -> void
			methodTable.Add(new MethodDefinitionRow(
				SegmentReference.Null, MethodImplAttributes.PreserveSig,
				MethodAttributes.Static | MethodAttributes.PInvokeImpl,
				stringsStreamBuffer.GetStringIndex("GetModuleFileNameW"),
				blobStreamBuffer.GetBlobIndex(module, new DummyProvider(),
					MethodSignature.CreateStatic(module.CorLibTypeFactory.Void, new[] {
						module.CorLibTypeFactory.IntPtr, module.CorLibTypeFactory.IntPtr,
						module.CorLibTypeFactory.UInt32
					}), ThrowErrorListener.Instance), 1));
			// 3: PathFindFileNameW (shlwapi): (pszPath) -> IntPtr
			methodTable.Add(new MethodDefinitionRow(
				SegmentReference.Null, MethodImplAttributes.PreserveSig,
				MethodAttributes.Static | MethodAttributes.PInvokeImpl,
				stringsStreamBuffer.GetStringIndex("PathFindFileNameW"),
				blobStreamBuffer.GetBlobIndex(module, new DummyProvider(),
					MethodSignature.CreateStatic(module.CorLibTypeFactory.IntPtr,
						new[] { module.CorLibTypeFactory.IntPtr }), ThrowErrorListener.Instance), 1));
			// 4: GetFileVersionInfoW (version): (lpszFileName, dwHandle, dwLen, lpData) -> Int32 (BOOL)
			methodTable.Add(new MethodDefinitionRow(
				SegmentReference.Null, MethodImplAttributes.PreserveSig,
				MethodAttributes.Static | MethodAttributes.PInvokeImpl,
				stringsStreamBuffer.GetStringIndex("GetFileVersionInfoW"),
				blobStreamBuffer.GetBlobIndex(module, new DummyProvider(),
					MethodSignature.CreateStatic(module.CorLibTypeFactory.Int32, new[] {
						module.CorLibTypeFactory.IntPtr, module.CorLibTypeFactory.UInt32,
						module.CorLibTypeFactory.UInt32, module.CorLibTypeFactory.IntPtr
					}), ThrowErrorListener.Instance), 1));
			// 5: VerQueryValueW (version): (pBlock, lpSubBlock, lplpBuffer, puLen) -> Int32 (BOOL)
			methodTable.Add(new MethodDefinitionRow(
				SegmentReference.Null, MethodImplAttributes.PreserveSig,
				MethodAttributes.Static | MethodAttributes.PInvokeImpl,
				stringsStreamBuffer.GetStringIndex("VerQueryValueW"),
				blobStreamBuffer.GetBlobIndex(module, new DummyProvider(),
					MethodSignature.CreateStatic(module.CorLibTypeFactory.Int32, new[] {
						module.CorLibTypeFactory.IntPtr, module.CorLibTypeFactory.IntPtr,
						module.CorLibTypeFactory.IntPtr, module.CorLibTypeFactory.IntPtr
					}), ThrowErrorListener.Instance), 1));

			// Main (method #6) — fat CIL body (code > 63 bytes, tiny format limit).
			// IL layout (code stream offsets, before 12-byte fat header):
			//   [0]  ldc.i4 0            hModule=0 for GetModuleFileNameW
			//   [5]  ldc.i4 [pathBuf]    PATCH @6
			//   [10] ldc.i4 260
			//   [15] call  Method#2      GetModuleFileNameW(0, pathBuf, 260)
			//   [20] ldc.i4 [pathBuf]    PATCH @21
			//   [25] ldc.i4 0            dwHandle=0
			//   [30] ldc.i4 4096         dwLen
			//   [35] ldc.i4 [viBuf]      PATCH @36
			//   [40] call  Method#4      GetFileVersionInfoW → BOOL on stack
			//   [45] brfalse.s 55        → FALLBACK @102 (next=47, 102-47=55)
			//   [47] ldc.i4 [viBuf]      PATCH @48
			//   [52] ldc.i4 [subBlock]   PATCH @53
			//   [57] ldc.i4 [pValueBuf]  PATCH @58
			//   [62] ldc.i4 [lenBuf]     PATCH @63
			//   [67] call  Method#5      VerQueryValueW → BOOL on stack
			//   [72] brfalse.s 28        → FALLBACK @102 (next=74, 102-74=28)
			//   [74] ldc.i4 0            hWnd
			//   [79] ldc.i4 [text]       PATCH @80
			//   [84] ldc.i4 [pValueBuf]  PATCH @85
			//   [89] ldind.i             *pValueBuf → title pointer
			//   [90] ldc.i4 0            uType
			//   [95] call  Method#1      MessageBoxW(0, text, titlePtr, 0)
			//   [100] br.s DONE          → @132 or @137 (offset 30 or 35)
			//   FALLBACK @102:
			//   [102] ldc.i4 0           hWnd
			//   [107] ldc.i4 [text]      PATCH @108
			//   [112] ldc.i4 [pathBuf]   PATCH @113
			//   [117] call  Method#3     PathFindFileNameW(pathBuf) → filenamePtr
			//   [122] ldc.i4 0           uType
			//   [127] call  Method#1     MessageBoxW(0, text, filenamePtr, 0)
			//   DONE @132 [or @137 if ExitCode!=0]:
			//   [132] ldc.i4 ExitCode    (only if ExitCode != 0)
			//   [132|137] ret
			// Patch offsets in segment = code offset + 12 (fat header size).
			using (var codeStream = new MemoryStream()) {
				Action<int> writeLdc = v => {
					codeStream.WriteByte(0x20);
					var b = BitConverter.GetBytes(v);
					codeStream.Write(b, 0, 4);
				};
				Action<int> writeCall = m => {
					codeStream.WriteByte(0x28);
					var b = BitConverter.GetBytes(0x06000000 | m);
					codeStream.Write(b, 0, 4);
				};

			writeLdc(0);       // [0]  hModule=0
			writeLdc(0);       // [5]  pathBuf  PATCH@6
			writeLdc(260);     // [10] nSize
			writeCall(2);      // [15] GetModuleFileNameW

			writeLdc(0);       // [20] pathBuf  PATCH@21
			writeLdc(0);       // [25] dwHandle=0
			writeLdc(4096);    // [30] dwLen
			writeLdc(0);       // [35] viBuf    PATCH@36
			writeCall(4);      // [40] GetFileVersionInfoW → BOOL

			codeStream.WriteByte(0x2C); // [45] brfalse.s
			codeStream.WriteByte(55);   // [46] → FALLBACK @102 (next=47, 102-47=55)

			writeLdc(0);       // [47] viBuf       PATCH@48
			writeLdc(0);       // [52] subBlockStr  PATCH@53
			writeLdc(0);       // [57] pValueBuf    PATCH@58
			writeLdc(0);       // [62] lenBuf       PATCH@63
			writeCall(5);      // [67] VerQueryValueW → BOOL

			codeStream.WriteByte(0x2C); // [72] brfalse.s
			codeStream.WriteByte(28);   // [73] → FALLBACK @102 (next=74, 102-74=28)

			writeLdc(0);       // [74] hWnd
			writeLdc(0);       // [79] text      PATCH@80
			writeLdc(0);       // [84] pValueBuf PATCH@85
			codeStream.WriteByte(0x4D); // [89] ldind.i → dereference pValueBuf
			writeLdc(0);       // [90] uType=0
			writeCall(1);      // [95] MessageBoxW(0, text, titlePtr, 0)

			codeStream.WriteByte(0x2B); // [100] br.s
			codeStream.WriteByte((byte)(30 + (ExitCode != 0 ? 5 : 0))); // [101] → DONE

			// FALLBACK @102
			writeLdc(0);       // [102] hWnd
			writeLdc(0);       // [107] text     PATCH@108
			writeLdc(0);       // [112] pathBuf  PATCH@113
			writeCall(3);      // [117] PathFindFileNameW(pathBuf) → filenamePtr
			writeLdc(0);       // [122] uType=0
			writeCall(1);      // [127] MessageBoxW(0, text, filenamePtr, 0)

			// DONE @132
			if (ExitCode != 0) writeLdc(ExitCode); // [132] only when needed
				codeStream.WriteByte(0x2A); // ret

				byte[] code = codeStream.ToArray();
				// Fat method header: flags=0x3003 (fat, hdrSize=3dwords), MaxStack=4, CodeSize, LocalVarSigTok=0
				byte[] header = {
					0x03, 0x30, 4, 0,
					(byte)code.Length, (byte)(code.Length >> 8), (byte)(code.Length >> 16), (byte)(code.Length >> 24),
					0, 0, 0, 0
				};
				byte[] fullMethod = new byte[header.Length + code.Length];
				Buffer.BlockCopy(header, 0, fullMethod, 0, header.Length);
				Buffer.BlockCopy(code, 0, fullMethod, header.Length, code.Length);

				// Patch offsets = code stream offset of int32 operand + 12 (fat header)
				var body = new DataSegment(fullMethod).AsPatchedSegment();
				body = body.Patch(12 +  6, AddressFixupType.Absolute32BitAddress, new Symbol(pathBufSeg.ToReference()));
				body = body.Patch(12 + 21, AddressFixupType.Absolute32BitAddress, new Symbol(pathBufSeg.ToReference()));
				body = body.Patch(12 + 36, AddressFixupType.Absolute32BitAddress, new Symbol(viBufSeg.ToReference()));
				body = body.Patch(12 + 48, AddressFixupType.Absolute32BitAddress, new Symbol(viBufSeg.ToReference()));
				body = body.Patch(12 + 53, AddressFixupType.Absolute32BitAddress, new Symbol(subBlockStr.ToReference()));
				body = body.Patch(12 + 58, AddressFixupType.Absolute32BitAddress, new Symbol(pValueBufSeg.ToReference()));
				body = body.Patch(12 + 63, AddressFixupType.Absolute32BitAddress, new Symbol(lenBufSeg.ToReference()));
				body = body.Patch(12 + 80, AddressFixupType.Absolute32BitAddress, new Symbol(textSegment.ToReference()));
				body = body.Patch(12 + 85, AddressFixupType.Absolute32BitAddress, new Symbol(pValueBufSeg.ToReference()));
				body = body.Patch(12 + 108, AddressFixupType.Absolute32BitAddress, new Symbol(textSegment.ToReference()));
				body = body.Patch(12 + 113, AddressFixupType.Absolute32BitAddress, new Symbol(pathBufSeg.ToReference()));

				var retype = module.CorLibTypeFactory.Void;
				if (ExitCode != 0) retype = module.CorLibTypeFactory.Int32;
				methodTable.Add(new MethodDefinitionRow(
					body.ToReference(), 0, MethodAttributes.Static, 0,
					blobStreamBuffer.GetBlobIndex(module, new DummyProvider(),
						MethodSignature.CreateStatic(retype), ThrowErrorListener.Instance), 1));
			}

			// Module references: 1=user32, 2=kernel32, 3=shlwapi, 4=version
			tablesStream.GetTable<ModuleReferenceRow>().Add(new ModuleReferenceRow(stringsStreamBuffer.GetStringIndex("user32")));
			tablesStream.GetTable<ModuleReferenceRow>().Add(new ModuleReferenceRow(stringsStreamBuffer.GetStringIndex("kernel32")));
			tablesStream.GetTable<ModuleReferenceRow>().Add(new ModuleReferenceRow(stringsStreamBuffer.GetStringIndex("shlwapi")));
			tablesStream.GetTable<ModuleReferenceRow>().Add(new ModuleReferenceRow(stringsStreamBuffer.GetStringIndex("version")));

			tablesStream.GetTable<ImplementationMapRow>().Add(new ImplementationMapRow(
				ImplementationMapAttributes.CallConvStdcall,
				tablesStream.GetIndexEncoder(CodedIndex.MemberForwarded).EncodeToken(new MetadataToken(TableIndex.Method, 1)),
				stringsStreamBuffer.GetStringIndex("MessageBoxW"), 1));
			tablesStream.GetTable<ImplementationMapRow>().Add(new ImplementationMapRow(
				ImplementationMapAttributes.CallConvStdcall,
				tablesStream.GetIndexEncoder(CodedIndex.MemberForwarded).EncodeToken(new MetadataToken(TableIndex.Method, 2)),
				stringsStreamBuffer.GetStringIndex("GetModuleFileNameW"), 2));
			tablesStream.GetTable<ImplementationMapRow>().Add(new ImplementationMapRow(
				ImplementationMapAttributes.CallConvStdcall,
				tablesStream.GetIndexEncoder(CodedIndex.MemberForwarded).EncodeToken(new MetadataToken(TableIndex.Method, 3)),
				stringsStreamBuffer.GetStringIndex("PathFindFileNameW"), 3));
			tablesStream.GetTable<ImplementationMapRow>().Add(new ImplementationMapRow(
				ImplementationMapAttributes.CallConvStdcall,
				tablesStream.GetIndexEncoder(CodedIndex.MemberForwarded).EncodeToken(new MetadataToken(TableIndex.Method, 4)),
				stringsStreamBuffer.GetStringIndex("GetFileVersionInfoW"), 4));
			tablesStream.GetTable<ImplementationMapRow>().Add(new ImplementationMapRow(
				ImplementationMapAttributes.CallConvStdcall,
				tablesStream.GetIndexEncoder(CodedIndex.MemberForwarded).EncodeToken(new MetadataToken(TableIndex.Method, 5)),
				stringsStreamBuffer.GetStringIndex("VerQueryValueW"), 4));

			tablesStream.GetTable<AssemblyDefinitionRow>().Add(new AssemblyDefinitionRow(
				0, 1, 0, 0, 0, 0, 0,
				stringsStreamBuffer.GetStringIndex("user32"), 0));

			var metadataDirectory = new MetadataDirectory {
				VersionString = targetRuntime == "Framework2.0" ? "v2.0." : "v4.0."
			};
			metadataDirectory.Streams.Add(tablesStream);
			metadataDirectory.Streams.Add(blobStreamBuffer.CreateStream());
			metadataDirectory.Streams.Add(stringsStreamBuffer.CreateStream());
			image.DotNetDirectory = new DotNetDirectory {
				// Main is method #6 (1=MessageBoxW,2=GetModuleFileNameW,3=PathFindFileNameW,4=GetFileVersionInfoW,5=VerQueryValueW,6=Main)
				EntryPoint = new MetadataToken(TableIndex.Method, 6u),
				Metadata = metadataDirectory
			};
			if (architecture == "anycpu")
				image.DotNetDirectory.Flags &= ~DotNetDirectoryFlags.Bit32Required;

			var result = new Program();
			result.Image = image;
			// Read-only data: text + VerQueryValueW subBlock path (both in .text)
			var roData = new SegmentBuilder();
			roData.Add(textSegment);
			roData.Add(subBlockStr, 2);
			result.OutSegment = roData;
			// Writable BSS data (in .data)
			var bssData = new SegmentBuilder();
			bssData.Add(pathBufSeg);
			bssData.Add(viBufSeg);
			bssData.Add(pValueBufSeg);
			bssData.Add(lenBufSeg);
			result.WritableSegment = bssData;
			return result;
		}

		private ISegment OutSegment;
		private ISegment WritableSegment;
		private PEImage Image;
		public void Build(string OutFile) {
			// Do NOT substitute ManagedPEFileBuilder: size would grow (see DESIGN at top of file).
			// OutSegment (read-only constants) → .text; WritableSegment (e.g. path buffer) → .data
			var file = new MinimalPEFileBuilder(OutSegment, WritableSegment).CreateFile(this.Image);
			file.Write(OutFile);
		}
		public void SetWin32Icon(string IconFile) {
			byte[] header = File.ReadAllBytes(IconFile);
			if (header.Length < 22) return;
			ushort count = BitConverter.ToUInt16(header, 4);
			if (count == 0) return;
			// First icon directory entry: width, height, colors, reserved, planes, bpp, size, offset
			byte w = header[6], h = header[7];
			ushort planes = BitConverter.ToUInt16(header, 10);
			ushort bpp = BitConverter.ToUInt16(header, 12);
			uint size = BitConverter.ToUInt32(header, 14);
			uint offset = BitConverter.ToUInt32(header, 18);
			if (offset + size > (uint)header.Length) return;
			byte[] iconBytes = new byte[size];
			Buffer.BlockCopy(header, (int)offset, iconBytes, 0, (int)size);

			var entry = new IconEntry(1, 0) {
				Width = w,
				Height = h,
				ColorCount = 0,
				Planes = planes,
				BitsPerPixel = bpp,
				PixelData = new DataSegment(iconBytes)
			};
			var group = new IconGroup(1u, 0u) { Type = IconType.Icon };
			group.Icons.Add(entry);
			var iconResource = new IconResource(IconType.Icon);
			iconResource.Groups.Add(group);

			if (this.Image.Resources == null) this.Image.Resources = new ResourceDirectory(0u);
			iconResource.InsertIntoDirectory(this.Image.Resources);
		}
		public void SetAssemblyInfo(string description, string company, string title, string product, string copyright, string trademark, string version) {
			// Create new version resource.
			var versionResource = new VersionInfoResource();
			if (string.IsNullOrEmpty(version)) version = "0.0.0.0";

			var TypedVersion = new System.Version(version);
			version = TypedVersion.ToString();

			// Add info.
			var fixedVersionInfo = new FixedVersionInfo {
				FileVersion = TypedVersion,
				ProductVersion = TypedVersion,
				FileDate = (ulong)DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
				FileType = FileType.App,
				FileOS = FileOS.Windows32,
				FileSubType = FileSubType.DriverInstallable,
			};
			versionResource.FixedVersionInfo = fixedVersionInfo;

			// Add strings.
			var stringFileInfo = new StringFileInfo();
			var stringTable = new StringTable(0, 0x4b0){
				{ StringTable.ProductNameKey, product },
				{ StringTable.FileVersionKey, version },
				{ StringTable.ProductVersionKey, version },
				{ StringTable.FileDescriptionKey, title },
				{ StringTable.CommentsKey, description },
				{ StringTable.LegalCopyrightKey, copyright }
			};

			stringFileInfo.Tables.Add(stringTable);
			versionResource.AddEntry(stringFileInfo);

			// Register translation.
			var varFileInfo = new VarFileInfo();
			var varTable = new VarTable();
			varTable.Values.Add(0x4b00000);
			varFileInfo.Tables.Add(varTable);
			versionResource.AddEntry(varFileInfo);

			// Add to resources.
			if (this.Image.Resources == null) this.Image.Resources = new ResourceDirectory(0u);
			versionResource.InsertIntoDirectory(this.Image.Resources);
		}
	}

	internal class DummyProvider: ITypeCodedIndexProvider {
		public uint GetTypeDefOrRefIndex(ITypeDefOrRef type, object extraArgument) {
			throw new NotImplementedException();
		}
	}

	/// <summary>
	/// Minimal PE: FileAlignment 512, SectionAlignment 4096 (loader requires 4K section alignment), .text only,
	/// minimal data directories. Achieves 1024 bytes. Output string is passed into builder and laid out inside .text
	/// so CIL patch gets correct RVA. 512 bytes total is not possible (PE headers + one section >= 1024).
	/// </summary>
	internal sealed class MinimalPEFileBuilder : ManagedPEFileBuilder {
		private readonly ISegment _extraSectionData;
		private readonly ISegment _writableData;

		public MinimalPEFileBuilder(ISegment extraSectionData = null, ISegment writableData = null) {
			_extraSectionData = extraSectionData;
			_writableData = writableData;
		}

		protected override uint GetFileAlignment(PEFileBuilderContext context, PEFile outputFile) { return 512; }
		// Section alignment 4096 for loader; file alignment 512 for size.
		protected override uint GetSectionAlignment(PEFileBuilderContext context, PEFile outputFile) { return 4096; }

		protected override IEnumerable<PESection> CreateSections(PEFileBuilderContext context) {
			yield return CreateTextSection(context);
			// 可写数据（如 GetModuleFileNameW 路径缓冲区）放独立 .data 段，避免 .text 带写权限
			if (_writableData != null) {
				yield return new PESection(".data",
					SectionFlags.ContentUninitializedData | SectionFlags.MemoryRead | SectionFlags.MemoryWrite,
					_writableData);
			}
			// 有 Win32 资源（如 icon、版本信息）时添加 .rsrc 段
			if (context.Image.Resources != null) {
				yield return new PESection(".rsrc",
					SectionFlags.ContentInitializedData | SectionFlags.MemoryRead,
					context.ResourceDirectory);
			}
		}

		protected override void AssignDataDirectories(PEFileBuilderContext context, PEFile outputFile) {
			base.AssignDataDirectories(context, outputFile);
			outputFile.OptionalHeader.SetDataDirectory(DataDirectoryIndex.BaseRelocationDirectory, (ISegment)null);
			outputFile.OptionalHeader.SetDataDirectory(DataDirectoryIndex.DebugDirectory, (ISegment)null);
			if (context.Image.Resources == null)
				outputFile.OptionalHeader.SetDataDirectory(DataDirectoryIndex.ResourceDirectory, (ISegment)null);
			outputFile.OptionalHeader.SetDataDirectory(DataDirectoryIndex.ExportDirectory, (ISegment)null);
		}

		protected override PESection CreateTextSection(PEFileBuilderContext context) {
			var contents = new SegmentBuilder();
			if (!context.ImportDirectory.IsEmpty) {
				contents.Add(context.ImportDirectory.ImportAddressDirectory);
			}
			var dotNet = context.Image.DotNetDirectory;
			if (dotNet != null) {
				contents.Add(dotNet);
				contents.Add(context.FieldRvaTable);
				contents.Add(context.MethodBodyTable);
				if (dotNet.Metadata != null) contents.Add(dotNet.Metadata, 4);
				if (dotNet.DotNetResources != null) contents.Add(dotNet.DotNetResources, 4);
				if (dotNet.StrongName != null) contents.Add(dotNet.StrongName, 4);
				if (dotNet.VTableFixups != null && dotNet.VTableFixups.Count > 0) contents.Add(dotNet.VTableFixups);
				if (dotNet.ExportAddressTable != null) contents.Add(dotNet.ExportAddressTable, 4);
				if (dotNet.ManagedNativeHeader != null) contents.Add(dotNet.ManagedNativeHeader, 4);
			}
			if (!context.ImportDirectory.IsEmpty) {
				contents.Add(context.ImportDirectory);
			}
			if (_extraSectionData != null)
				contents.Add(_extraSectionData);
			return new PESection(".text",
				SectionFlags.ContentCode | SectionFlags.MemoryExecute | SectionFlags.MemoryRead,
				contents);
		}
	}
}
