// Uses AsmResolver to read embedded script resources from a ps12exe-built exe
// and return the original PowerShell script text. Exposed via the exe21sp PowerShell helper.
using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Text;
using AsmResolver;
using AsmResolver.DotNet;
using AsmResolver.PE;
using AsmResolver.PE.File;
using AsmResolver.PE.Win32Resources;

namespace exe21sp {
	/// <summary>
	/// 当前宿主没有 BrotliStream（.NET Framework 不提供），需要转交 pwsh / .NET Core 解压。
	/// </summary>
	public sealed class BrotliUnavailableException : Exception { }

	public static class Extractor {
		/// <summary>
		/// Extracts the embedded PowerShell script from a ps12exe-built executable.
		/// </summary>
		/// <param name="exePath">Full path to the .exe file.</param>
		/// <returns>
		/// For normal ps12exe exes: the original PowerShell script from an embedded resource.
		/// For TinySharp-compiled exes: a synthesized script that prints the captured output string and,
		/// if applicable, appends an exit statement with the recorded exit code.
		/// Returns null if the exe is not a ps12exe output or payload cannot be recovered.
		/// </returns>
		public static string ExtractScriptFromExe(string exePath) {
			if (string.IsNullOrEmpty(exePath) || !File.Exists(exePath))
				return null;
			// First, try the standard program frame: embedded main.ps1 resource.
			var script = TryExtractFromFrame(exePath);
			if (script != null)
				return script;

			// Fallback: TinySharp-compiled minimal exe (no script resource).
			return TryExtractFromTinySharp(exePath);
		}

		private static string TryExtractFromFrame(string exePath) {
			// 普通托管 exe 的镜像在偏移 0；Core 的单文件 exe 是原生 apphost 后追加托管负载，
			// 因此扫描文件内所有内嵌 PE 镜像，逐个尝试提取。
			foreach (var image in EnumerateEmbeddedImages(File.ReadAllBytes(exePath))) {
				try {
					var module = ModuleDefinition.FromBytes(image);
					var script = TryExtractFromModule(module);
					if (script != null)
						return script;

					// Non-const exes wrap the real assembly in the launcher's "main" resource.
					// Unwrap it and look for the main.ps1 script resource inside that payload.
					var payload = TryGetLauncherPayload(module);
					if (payload != null)
						return TryExtractFromModule(ModuleDefinition.FromBytes(payload));
				}
				catch (BrotliUnavailableException) {
					// 需要 .NET Core 才能解压的 Core 负载，交给上层转交 pwsh。
					throw;
				}
				catch {
					// 非有效 .NET 模块（如原生 apphost）或读取错误。
				}
			}
			return null;
		}

		/// <summary>
		/// 逐个产出文件内疑似 PE 镜像的字节切片（从每个 "MZ" 且带有效 PE 头的偏移到文件末尾）。
		/// 单文件发布的 exe 把托管程序集追加在原生 apphost 之后，需要这样找出来。
		/// </summary>
		private static IEnumerable<byte[]> EnumerateEmbeddedImages(byte[] fileBytes) {
			for (int offset = 0; offset + 0x40 <= fileBytes.Length; offset++) {
				if (fileBytes[offset] != 'M' || fileBytes[offset + 1] != 'Z')
					continue;
				uint peHeaderOffset = BitConverter.ToUInt32(fileBytes, offset + 0x3C);
				if (peHeaderOffset < 0x40 || peHeaderOffset > 0x1000)
					continue;
				long peOffset = offset + (long)peHeaderOffset;
				if (peOffset + 4 > fileBytes.Length)
					continue;
				if (fileBytes[peOffset] != 'P' || fileBytes[peOffset + 1] != 'E' || fileBytes[peOffset + 2] != 0 || fileBytes[peOffset + 3] != 0)
					continue;
				var image = new byte[fileBytes.Length - offset];
				Buffer.BlockCopy(fileBytes, offset, image, 0, image.Length);
				yield return image;
			}
		}

		private static string TryExtractFromModule(ModuleDefinition module) {
			foreach (var resource in module.Resources) {
				if (!resource.IsEmbedded)
					continue;

				string name = object.ReferenceEquals(resource.Name, null) ? null : resource.Name.ToString();
				// 脚本以未压缩的 .ps1 资源内嵌（标准 frame 是 main.ps1）。
				if (name != null && name.EndsWith(".ps1", StringComparison.OrdinalIgnoreCase)) {
					var raw = resource.GetData();
					if (raw == null || raw.Length == 0)
						continue;

					using (var ms = new MemoryStream(raw))
					// Detect encoding from BOM when present; default to UTF-8 without BOM.
					using (var reader = new StreamReader(ms, Encoding.UTF8, detectEncodingFromByteOrderMarks: true)) {
						return reader.ReadToEnd();
					}
				}
			}
			return null;
		}

		private static byte[] TryGetLauncherPayload(ModuleDefinition module) {
			foreach (var resource in module.Resources) {
				if (!resource.IsEmbedded)
					continue;
				string name = object.ReferenceEquals(resource.Name, null) ? null : resource.Name.ToString();
				if (!string.Equals(name, "main", StringComparison.OrdinalIgnoreCase))
					continue;

				var raw = resource.GetData();
				if (raw == null || raw.Length == 0)
					return null;

				return DecompressLauncherPayload(raw);
			}
			return null;
		}

		/// <summary>
		/// 解压 launcher 的 "main" 负载：Windows PowerShell 构建是 gzip，Core 构建是 Brotli。
		/// BrotliStream 不在 .NET Framework 中，故用反射取；不可用时抛 <see cref="BrotliUnavailableException"/>，
		/// 由 exe21sp 转交 pwsh 处理。
		/// </summary>
		private static byte[] DecompressLauncherPayload(byte[] raw) {
			using (var ms = new MemoryStream(raw)) {
				// gzip 流以 1F 8B 开头；否则视为 Brotli（Brotli 无固定魔数）。
				Stream decompressor = raw.Length >= 2 && raw[0] == 0x1F && raw[1] == 0x8B
					? new GZipStream(ms, CompressionMode.Decompress)
					: CreateBrotliDecompressor(ms);
				using (decompressor)
				using (var outMs = new MemoryStream()) {
					decompressor.CopyTo(outMs);
					return outMs.ToArray();
				}
			}
		}

		private static Stream CreateBrotliDecompressor(Stream source) {
			var brotliType = Type.GetType("System.IO.Compression.BrotliStream, System.IO.Compression.Brotli", false);
			if (brotliType == null)
				throw new BrotliUnavailableException();
			return (Stream)Activator.CreateInstance(brotliType, source, CompressionMode.Decompress);
		}

		/// <summary>
		/// Rebuilds the Win32 icon embedded in a ps12exe-built executable into a standalone .ico file.
		/// ps12exe 编译时通过 /win32icon（CodeDom）或 ApplicationIcon（Core）把图标写入最外层 PE，
		/// 反编译时把它还原出来，供 exe21sp 释放在输出目录并由 #_pragma icon 重新引用。
		/// </summary>
		/// <param name="exePath">Full path to the .exe file.</param>
		/// <returns>The .ico file bytes, or null when the exe has no icon resource.</returns>
		public static byte[] ExtractIconFromExe(string exePath) {
			if (string.IsNullOrEmpty(exePath) || !File.Exists(exePath))
				return null;
			try {
				return ExtractIconFromImage(PEImage.FromFile(exePath));
			}
			catch {
				return null;
			}
		}

		private static byte[] ExtractIconFromImage(PEImage image) {
			var root = image.Resources;
			if (root == null)
				return null;
			ResourceDirectory groupDir;
			ResourceDirectory iconDir;
			if (!root.TryGetDirectory(ResourceType.GroupIcon, out groupDir) || groupDir == null)
				return null;
			if (!root.TryGetDirectory(ResourceType.Icon, out iconDir) || iconDir == null)
				return null;

			// 可能有多个图标组（不同语言/名称），取第一个能完整还原的。
			foreach (var groupEntry in groupDir.Entries) {
				if (!groupEntry.IsDirectory)
					continue;
				var groupBytes = ReadFirstEntryBytes((ResourceDirectory)groupEntry);
				if (groupBytes == null)
					continue;
				var ico = BuildIconFile(groupBytes, iconDir);
				if (ico != null)
					return ico;
			}
			return null;
		}

		/// <summary>
		/// 深度优先读取资源目录下第一份数据。PE 资源树是 类型 → 名称/ID → 语言 → 数据，
		/// 这里不假设层数，直接找叶子数据。
		/// </summary>
		private static byte[] ReadFirstEntryBytes(ResourceDirectory directory) {
			foreach (var entry in directory.Entries) {
				if (entry.IsData) {
					var data = entry as ResourceData;
					var bytes = data == null ? null : ReadSegmentBytes(data.Contents);
					if (bytes != null)
						return bytes;
				}
				else if (entry.IsDirectory) {
					var bytes = ReadFirstEntryBytes((ResourceDirectory)entry);
					if (bytes != null)
						return bytes;
				}
			}
			return null;
		}

		private static byte[] ReadSegmentBytes(ISegment segment) {
			var readable = segment as IReadableSegment;
			return readable == null ? null : Extensions.ToArray(readable);
		}

		/// <summary>
		/// 按资源 ID 在 RT_ICON 目录里找图标图像数据。目录项里存的 ID 是 16 位。
		/// </summary>
		private static byte[] FindIconImageBytes(ResourceDirectory directory, uint id) {
			foreach (var entry in directory.Entries) {
				if (!entry.IsDirectory)
					continue;
				if (entry.Id == id) {
					var bytes = ReadFirstEntryBytes((ResourceDirectory)entry);
					if (bytes != null)
						return bytes;
				}
				var nested = FindIconImageBytes((ResourceDirectory)entry, id);
				if (nested != null)
					return nested;
			}
			return null;
		}

		/// <summary>
		/// 把 GRPICONDIR（RT_GROUP_ICON 数据）和对应的 RT_ICON 图像拼成一个标准 .ico 文件。
		/// 每个目录项 14 字节：宽/高/色数/保留 + 平面数 + 位深 + 数据大小 + 图标 ID。
		/// </summary>
		private static byte[] BuildIconFile(byte[] group, ResourceDirectory iconDir) {
			if (group == null || group.Length < 6)
				return null;
			int type = BitConverter.ToUInt16(group, 2);
			int count = BitConverter.ToUInt16(group, 4);
			if (type != 1 || count <= 0 || group.Length < 6 + count * 14)
				return null;

			var directory = new byte[count][];
			var images = new byte[count][];
			for (int i = 0; i < count; i++) {
				int offset = 6 + i * 14;
				ushort iconId = BitConverter.ToUInt16(group, offset + 12);
				var image = FindIconImageBytes(iconDir, iconId);
				if (image == null)
					return null;
				images[i] = image;

				var entry = new byte[16];
				entry[0] = group[offset];     // width
				entry[1] = group[offset + 1]; // height
				entry[2] = group[offset + 2]; // color count
				entry[3] = group[offset + 3]; // reserved
				Buffer.BlockCopy(group, offset + 4, entry, 4, 2); // planes
				Buffer.BlockCopy(group, offset + 6, entry, 6, 2); // bit count
				Buffer.BlockCopy(BitConverter.GetBytes((uint)image.Length), 0, entry, 8, 4);
				directory[i] = entry;
			}

			using (var output = new MemoryStream()) {
				output.Write(BitConverter.GetBytes((ushort)0), 0, 2);
				output.Write(BitConverter.GetBytes((ushort)1), 0, 2);
				output.Write(BitConverter.GetBytes((ushort)count), 0, 2);
				uint dataOffset = (uint)(6 + count * 16);
				for (int i = 0; i < count; i++) {
					Buffer.BlockCopy(BitConverter.GetBytes(dataOffset), 0, directory[i], 12, 4);
					output.Write(directory[i], 0, directory[i].Length);
					dataOffset += (uint)images[i].Length;
				}
				for (int i = 0; i < count; i++)
					output.Write(images[i], 0, images[i].Length);
				return output.ToArray();
			}
		}

		private static string TryExtractFromTinySharp(string exePath) {
			var peFile = PEFile.FromFile(exePath);
			// Only treat as TinySharp when the PE is a .NET assembly (has CLR header).
			// Otherwise native exes (e.g. notepad.exe) would yield garbage from .text.
			if (peFile.OptionalHeader == null)
				return null;
			var clrDir = peFile.OptionalHeader.GetDataDirectory(DataDirectoryIndex.ClrDirectory);
			if (clrDir.Size == 0 || !clrDir.IsPresentInPE)
				return null;

			// From here on we consider this a potential TinySharp exe; layout failures must throw.
			PESection section = null;
			foreach (var s in peFile.Sections) {
				if (!object.ReferenceEquals(s.Name, null) && s.Name.ToString() == ".text") {
					section = s;
					break;
				}
			}
			if (section == null)
				throw new InvalidOperationException("TinySharpNoTextSection");
			var size = (uint)Math.Min(section.GetPhysicalSize(), 1024 * 1024);
			if (size == 0)
				throw new InvalidOperationException("TinySharpTextSectionEmpty");
			var sectionReader = peFile.CreateReaderAtFileOffset(section.Offset, size);
			var raw = sectionReader.ReadBytes((int)sectionReader.Length);
			if (raw == null || raw.Length == 0)
				throw new InvalidOperationException("TinySharpCannotReadText");

			// Locate the message string by counting ldc.i4 VA references in the CIL region.
			// TinySharp patches the message address into every MessageBoxW call site (2× for the
			// two-path MessageBox build, 1× for console builds), while infrastructure strings
			// (e.g. VerQueryValueW subBlock path) are referenced only once.  The most-referenced
			// VA that maps to actual file content in .text is therefore the message — no content
			// heuristics needed.
			string message = FindMessageByVARefCount(raw, peFile.OptionalHeader.ImageBase, section);
			if (string.IsNullOrEmpty(message))
				throw new InvalidOperationException("TinySharpPayloadNotRecovered");

			// TinySharp embeds non-zero exit code as CIL: Ldc_I4 (0x20) + 4-byte LE + Ret (0x2A). Find last such sequence.
			int exitCode = TryDetectTinySharpExitCode(raw);

			var builder = new StringBuilder();
			var escaped = message.Replace("'", "''");
			builder.Append("'").Append(escaped).Append("'");
			if (exitCode != 0)
				builder.Append("\nexit ").Append(exitCode);
			return builder.ToString();
		}

		/// <summary>
		/// Scans .text for TinySharp main's trailing CIL: Ldc_I4 (0x20) + 4-byte LE exit code + Ret (0x2A).
		/// Only scans the first 2KB (CIL region); string data at end of .text could otherwise false-match.
		/// Returns the last matching exit code, or 0 if not found / not plausible.
		/// </summary>
		private static int TryDetectTinySharpExitCode(byte[] raw) {
			const byte CilLdcI4 = 0x20;
			const byte CilRet = 0x2A;
			const int MinPlausible = -32768;
			const int MaxPlausible = 32767;
			int scanLen = Math.Min(raw.Length - 6, 2048);
			if (scanLen < 0) return 0;
			int lastExit = 0;
			for (int i = 0; i <= scanLen; i++) {
				if (raw[i] != CilLdcI4 || raw[i + 5] != CilRet)
					continue;
				int code = BitConverter.ToInt32(raw, i + 1);
				if (code >= MinPlausible && code <= MaxPlausible)
					lastExit = code;
			}
			return lastExit;
		}

		private static bool IsPrintableAscii(string s) {
			foreach (var c in s)
				if (c < 32 || c > 126)
					return false;
			return true;
		}

		private static bool IsPrintableUnicode(string s) {
			foreach (var c in s)
				if (char.IsControl(c) && c != '\r' && c != '\n' && c != '\t')
					return false;
			return true;
		}

		/// <summary>
		/// Scans the first 2 KB of .text (the CIL region) for ldc.i4 operands whose value
		/// is a VA within the physical file content of .text.  Counts how many times each
		/// such VA appears; the most-referenced one is the message string (TinySharp MessageBox
		/// patches it at every call site — 2×, whereas infra strings like the VerQueryValueW
		/// subBlock path appear only 1×).  No content heuristics are used.
		/// </summary>
		private static string FindMessageByVARefCount(byte[] raw, ulong imageBase, PESection section) {
			ulong textVABase = imageBase + section.Rva;
			// Parallel arrays instead of Dictionary<> to avoid requiring extra assembly references.
			// At most a handful of distinct .text VAs appear as ldc.i4 operands in 2 KB of CIL.
			const int MaxSlots = 64;
			uint[] vaKeys   = new uint[MaxSlots];
			int[]  vaCounts = new int[MaxSlots];
			int    slotCount = 0;
			int cilEnd = Math.Min(raw.Length - 6, 2048);
			for (int i = 0; i <= cilEnd; i++) {
				if (raw[i] != 0x20) continue; // ldc.i4 opcode
				uint operand = (uint)BitConverter.ToInt32(raw, i + 1);
				// TinySharp imageBase < 2^32, so the ldc.i4 operand IS the full 32-bit VA.
				ulong va = (imageBase & 0xFFFFFFFF00000000UL) | (ulong)operand;
				if (va < textVABase) continue;
				ulong fileOff = va - textVABase;
				if (fileOff >= (ulong)raw.Length) continue; // BSS/virtual — no file content
				// Linear search is fine; < 20 distinct candidates expected.
				int idx = -1;
				for (int j = 0; j < slotCount; j++) if (vaKeys[j] == operand) { idx = j; break; }
				if (idx < 0 && slotCount < MaxSlots) { vaKeys[slotCount] = operand; vaCounts[slotCount] = 1; slotCount++; }
				else if (idx >= 0) vaCounts[idx]++;
			}
			// Most-referenced VA = message; tiebreak by lowest file offset (message placed first).
			int bestCount = 0;
			ulong bestFileOff = ulong.MaxValue;
			uint bestOperand = 0;
			for (int j = 0; j < slotCount; j++) {
				ulong va = (imageBase & 0xFFFFFFFF00000000UL) | (ulong)vaKeys[j];
				ulong fileOff = va - textVABase;
				if (vaCounts[j] > bestCount || (vaCounts[j] == bestCount && fileOff < bestFileOff)) {
					bestCount = vaCounts[j]; bestFileOff = fileOff; bestOperand = vaKeys[j];
				}
			}
			if (bestOperand == 0) return null;
			int off = (int)bestFileOff;
			// Distinguish encoding by checking whether the second byte is a null (UTF-16LE pattern).
			// MessageBox / WriteConsoleW builds use Unicode (raw[off+1] == 0x00 for ASCII-range text).
			// puts builds use plain ASCII (raw[off+1] is a printable byte, not zero).
			bool looksUtf16 = (off + 1 < raw.Length && raw[off + 1] == 0);
			if (looksUtf16) {
				var msgU = TryReadNullTermUnicode(raw, off);
				return msgU ?? TryReadNullTermAscii(raw, off);
			} else {
				var msgA = TryReadNullTermAscii(raw, off);
				return msgA ?? TryReadNullTermUnicode(raw, off);
			}
		}

		private static string TryReadNullTermUnicode(byte[] raw, int offset) {
			if (offset < 0 || offset + 2 > raw.Length) return null;
			int end = offset;
			while (end + 1 < raw.Length && (raw[end] != 0 || raw[end + 1] != 0)) end += 2;
			if (end == offset || end - offset > 8192) return null;
			var s = Encoding.Unicode.GetString(raw, offset, end - offset);
			return IsPrintableUnicode(s) ? s : null;
		}

		private static string TryReadNullTermAscii(byte[] raw, int offset) {
			if (offset < 0 || offset >= raw.Length) return null;
			int end = offset;
			while (end < raw.Length && raw[end] != 0) end++;
			if (end == offset || end - offset > 8192) return null;
			var s = Encoding.ASCII.GetString(raw, offset, end - offset);
			return IsPrintableAscii(s) ? s : null;
		}
	}
}
