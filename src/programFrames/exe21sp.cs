// Uses AsmResolver to read embedded script resources from a ps12exe-built exe
// and return the original PowerShell script text. Exposed via the exe21sp PowerShell helper.
using System;
using System.IO;
using System.IO.Compression;
using System.Text;
using AsmResolver.DotNet;
using AsmResolver.PE.File;

namespace exe21sp {
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
			// First, try the standard program frame: embedded main.par resource.
			var script = TryExtractFromMainPar(exePath);
			if (script != null)
				return script;

			// Fallback: TinySharp-compiled minimal exe (no main.par).
			return TryExtractFromTinySharp(exePath);
		}

		private static string TryExtractFromMainPar(string exePath) {
			try {
				var module = ModuleDefinition.FromFile(exePath);
				foreach (var resource in module.Resources) {
					if (!resource.IsEmbedded)
						continue;

					string name = object.ReferenceEquals(resource.Name, null) ? null : resource.Name.ToString();
					if (string.Equals(name, "main.par", StringComparison.OrdinalIgnoreCase)) {
						var raw = resource.GetData();
						if (raw == null || raw.Length == 0)
							return null;

						using (var ms = new MemoryStream(raw))
						using (var gzip = new GZipStream(ms, CompressionMode.Decompress))
						using (var reader = new StreamReader(gzip, Encoding.UTF8)) {
							return reader.ReadToEnd();
						}
					}

					// Fallback: some frames may embed the plain script as a .ps1 resource instead of main.par.
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
			}
			catch {
				// Not a valid .NET module or read error.
			}
			return null;
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
