//code from https://blog.washi.dev/posts/tinysharp/
using System;
using System.IO;
using System.Text;
using AsmResolver;
using AsmResolver.DotNet;
using AsmResolver.DotNet.Builder.Metadata.Blob;
using AsmResolver.DotNet.Builder.Metadata.Strings;
using AsmResolver.DotNet.Code.Cil;
using AsmResolver.DotNet.Signatures;
using AsmResolver.IO;
using AsmResolver.PE;
using AsmResolver.PE.DotNet.Builder;
using AsmResolver.PE.Code;
using AsmResolver.PE.DotNet;
using AsmResolver.PE.DotNet.Cil;
using AsmResolver.PE.DotNet.Metadata;
using AsmResolver.PE.DotNet.Metadata.Tables;
using AsmResolver.PE.DotNet.Metadata.Tables.Rows;
using AsmResolver.PE.Win32Resources;
using AsmResolver.PE.Win32Resources.Icon;
using AsmResolver.PE.File;
using AsmResolver.PE.File.Headers;

namespace TinySharp {
	public class Program {
		public static PEFile Compile(
			string outputValue, string architecture = "x64", int ExitCode = 0
		) {
			string baseFunction = "_putws";
			var module = new ModuleDefinition("Dummy");

			// Segment containing our string to print.
			var segment = new DataSegment(Encoding.Unicode.GetBytes(outputValue+'\0'));

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
			methodTable.Add(new MethodDefinitionRow(
				SegmentReference.Null,
				MethodImplAttributes.PreserveSig,
				MethodAttributes.Static | MethodAttributes.PInvokeImpl,
				stringsStreamBuffer.GetStringIndex(baseFunction),
				blobStreamBuffer.GetBlobIndex(new DummyProvider(),
					MethodSignature.CreateStatic(module.CorLibTypeFactory.Void, module.CorLibTypeFactory.IntPtr), ThrowErrorListener.Instance),
				1
			));

			// Add main method calling puts.
			using(var codeStream = new MemoryStream()) {
				var assembler = new CilAssembler(new BinaryStreamWriter(codeStream), new CilOperandBuilder(new OriginalMetadataTokenProvider(null), ThrowErrorListener.Instance));
				assembler.WriteInstruction(new CilInstruction(CilOpCodes.Ldc_I4, 0x00000000)); // To be replaced with the address to the string to print (applied with a patch below).
				assembler.WriteInstruction(new CilInstruction(CilOpCodes.Call, new MetadataToken(TableIndex.Method, 1)));
				if(ExitCode!=0)
					assembler.WriteInstruction(new CilInstruction(CilOpCodes.Ldc_I4, ExitCode));
				assembler.WriteInstruction(new CilInstruction(CilOpCodes.Ret));

				var body = new CilRawTinyMethodBody(codeStream.ToArray())
					.AsPatchedSegment()
					.Patch(2, AddressFixupType.Absolute32BitAddress, new Symbol(segment.ToReference()));

				var retype=module.CorLibTypeFactory.Void;
				if(ExitCode!=0)
					retype=module.CorLibTypeFactory.Int32;

				methodTable.Add(new MethodDefinitionRow(
					body.ToReference(),
					0,
					MethodAttributes.Static,
					0,
					blobStreamBuffer.GetBlobIndex(new DummyProvider(),
						MethodSignature.CreateStatic(retype), ThrowErrorListener.Instance),
					1
				));
			}

			// Add urctbase module reference
			var baseLibrary = "ucrtbase";
			tablesStream.GetTable<ModuleReferenceRow>().Add(new ModuleReferenceRow(stringsStreamBuffer.GetStringIndex(baseLibrary)));

			// Add P/Invoke metadata to the puts method.
			tablesStream.GetTable<ImplementationMapRow>().Add(new ImplementationMapRow(
				ImplementationMapAttributes.CallConvCdecl,
				tablesStream.GetIndexEncoder(CodedIndex.MemberForwarded).EncodeToken(new MetadataToken(TableIndex.Method, 1)),
				stringsStreamBuffer.GetStringIndex(baseFunction),
				1
			));

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
			image.DotNetDirectory = new DotNetDirectory {
				EntryPoint = new MetadataToken(TableIndex.Method, 2),
				Metadata = new Metadata {
					VersionString = "v4.0.", // Needs the "." at the end. (original: v4.0.30319)
					Streams = {
						tablesStream,
						blobStreamBuffer.CreateStream(),
						stringsStreamBuffer.CreateStream()
					}
				}
			};
			if (architecture == "anycpu")
				image.DotNetDirectory.Flags &= ~DotNetDirectoryFlags.Bit32Required;

			// Assemble PE file.
			var file = new MyBuilder().CreateFile(image);

			// Put string to print in the padding data.
			file.ExtraSectionData = segment;

			return file;
		}
	}

	internal class DummyProvider : ITypeCodedIndexProvider {
		public uint GetTypeDefOrRefIndex(ITypeDefOrRef type) { throw new NotImplementedException(); }
	}

	public class MyBuilder : ManagedPEFileBuilder {
		protected override PESection CreateTextSection(IPEImage image, ManagedPEBuilderContext context) {
			// We override this method to only have it emit the bare minimum .text section.

			var methodTable = context.DotNetSegment.DotNetDirectory.Metadata.GetStream<TablesStream>().GetTable<MethodDefinitionRow>();

			for (uint rid = 1; rid <= methodTable.Count; rid++) {
				var methodRow = methodTable.GetByRid(rid);

				var bodySegment = methodRow.Body.IsBounded
					? methodRow.Body.GetSegment()
					: null;

				if (bodySegment != null) {
					context.DotNetSegment.MethodBodyTable.AddNativeBody(bodySegment, 4);
					methodRow.Body = bodySegment.ToReference();
				}
			}

			return new PESection(".text",
				SectionFlags.ContentCode | SectionFlags.MemoryRead,
				context.DotNetSegment);
		}
	}
}
