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

			// TinySharp places its output string at the end of .text; take the last null-terminated string.
			int bestAsciiEnd = -1, bestUnicodeEnd = -1;
			string bestAscii = null;
			string bestUnicode = null;
			for (int i = 0; i < raw.Length - 1; i++) {
				if (raw[i] == 0)
					continue;
				int end = i;
				while (end < raw.Length && raw[end] != 0)
					end++;
				if (end - i < 1 || end - i > 2048)
					continue;
				var candidate = Encoding.ASCII.GetString(raw, i, end - i);
				if (!IsPrintableAscii(candidate))
					continue;
				if (end > bestAsciiEnd) { bestAscii = candidate; bestAsciiEnd = end; }
			}
			for (int i = 0; i < raw.Length - 3; i += 2) {
				if (raw[i] == 0 && raw[i + 1] == 0)
					continue;
				int end = i;
				while (end + 1 < raw.Length && (raw[end] != 0 || raw[end + 1] != 0))
					end += 2;
				if (end - i < 2 || (end - i) / 2 > 2048)
					continue;
				var candidate = Encoding.Unicode.GetString(raw, i, end - i);
				if (!IsPrintableUnicode(candidate))
					continue;
				if (end > bestUnicodeEnd) { bestUnicode = candidate; bestUnicodeEnd = end; }
			}
			string message = null;
			if (bestAscii != null && bestAscii.Length >= 1 && (bestUnicode == null || !IsPrintableAscii(bestUnicode) || bestAsciiEnd >= bestUnicodeEnd))
				message = bestAscii;
			else if (bestUnicode != null)
				message = bestUnicode;
			else if (bestAscii != null)
				message = bestAscii;
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
	}
}

