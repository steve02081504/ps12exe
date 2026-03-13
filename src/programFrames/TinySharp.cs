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
			string outputValue = "Hello World!", int ExitCode = 0, bool hasOutput = true
		) {
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
		private DataSegment OutSegment;
		private PEImage Image;
		public void Build(string OutFile) {
			// Do NOT substitute ManagedPEFileBuilder: size would grow (see DESIGN at top of file).
			// Pass OutSegment into builder so it is laid out inside .text and CIL patch gets correct RVA.
			var file = new MinimalPEFileBuilder(OutSegment).CreateFile(this.Image);
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

		public MinimalPEFileBuilder(ISegment extraSectionData = null) {
			_extraSectionData = extraSectionData;
		}

		protected override uint GetFileAlignment(PEFileBuilderContext context, PEFile outputFile) { return 512; }
		// Section alignment 4096 for loader; file alignment 512 for size.
		protected override uint GetSectionAlignment(PEFileBuilderContext context, PEFile outputFile) { return 4096; }

		protected override IEnumerable<PESection> CreateSections(PEFileBuilderContext context) {
			yield return CreateTextSection(context);
		}

		protected override void AssignDataDirectories(PEFileBuilderContext context, PEFile outputFile) {
			base.AssignDataDirectories(context, outputFile);
			outputFile.OptionalHeader.SetDataDirectory(DataDirectoryIndex.BaseRelocationDirectory, (ISegment)null);
			outputFile.OptionalHeader.SetDataDirectory(DataDirectoryIndex.DebugDirectory, (ISegment)null);
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
