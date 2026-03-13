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
					string name = object.ReferenceEquals(resource.Name, null) ? null : resource.Name.ToString();
					// Resource may be "main.par" or e.g. "path\main.par" / "Namespace.main.par" depending on compiler.
					if (name != null && (string.Equals(name, "main.par", StringComparison.OrdinalIgnoreCase) || name.EndsWith("main.par", StringComparison.OrdinalIgnoreCase))) {
						if (!resource.IsEmbedded) continue; // need raw bytes from this module
						byte[] raw = null;
						try { raw = resource.GetData(); } catch { }
						if (raw == null || raw.Length == 0) return null;
						try {
							using (var ms = new MemoryStream(raw))
							using (var gzip = new GZipStream(ms, CompressionMode.Decompress))
							using (var reader = new StreamReader(gzip, Encoding.UTF8)) {
								return reader.ReadToEnd();
							}
						} catch {
							// not valid gzip or not UTF-8
						}
						return null;
					}

					// Fallback: some frames may embed the plain script as a .ps1 resource instead of main.par.
					if (name != null && name.EndsWith(".ps1", StringComparison.OrdinalIgnoreCase) && resource.IsEmbedded) {
						byte[] raw = null;
						try { raw = resource.GetData(); } catch { }
						if (raw == null || raw.Length == 0) continue;
						try {
							using (var ms = new MemoryStream(raw))
							using (var reader = new StreamReader(ms, new UTF8Encoding(false), detectEncodingFromByteOrderMarks: true)) {
								return reader.ReadToEnd();
							}
						} catch { }
					}
				}
			}
			catch {
				// Not a valid .NET module or read error.
			}
			return null;
		}

		private static string TryExtractFromTinySharp(string exePath) {
			try {
				var peFile = PEFile.FromFile(exePath);
				// Only attempt TinySharp extraction for .NET assemblies (e.g. no main.par).
				var opt = peFile.OptionalHeader;
				if (opt == null) return null;
				var clrDir = opt.GetDataDirectory(DataDirectoryIndex.ClrDirectory);
				if (!clrDir.IsPresentInPE) return null;

				PESection section = null;
				foreach (var s in peFile.Sections) {
					if (!object.ReferenceEquals(s.Name, null) && s.Name.ToString() == ".text") {
						section = s;
						break;
					}
				}
				if (section == null)
					return null;
				var size = (uint)Math.Min(section.GetPhysicalSize(), 1024 * 1024);
				if (size == 0)
					return null;
				// Read from file offset; section.CreateReader may not work for serialized PE from disk.
				var sectionReader = peFile.CreateReaderAtFileOffset(section.Offset, size);
				var raw = sectionReader.ReadBytes((int)sectionReader.Length);
				if (raw == null || raw.Length == 0)
					return null;

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
					if (bestAscii == null || candidate.Length > bestAscii.Length) bestAscii = candidate;
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
					if (bestUnicode == null || candidate.Length > bestUnicode.Length) bestUnicode = candidate;
				}
				// Prefer ASCII when it is substantial, to avoid picking Unicode mojibake from ASCII bytes.
				string message = null;
				if (bestAscii != null && bestAscii.Length >= 5 && (bestUnicode == null || !IsPrintableAscii(bestUnicode) || bestAscii.Length >= bestUnicode.Length))
					message = bestAscii;
				else if (bestUnicode != null)
					message = bestUnicode;
				else if (bestAscii != null)
					message = bestAscii;
				if (string.IsNullOrEmpty(message))
					return null;
				// Reject obvious non-script strings (e.g. .NET type names from .text).
				var trimmed = message.Trim();
				if (trimmed.StartsWith("System.", StringComparison.Ordinal) || trimmed.StartsWith("Microsoft.", StringComparison.Ordinal))
					return null;
				if (trimmed.Length > 0 && trimmed.Length < 10 && !char.IsLetter(trimmed[0]))
					return null;
				var builder = new StringBuilder();
				var escaped = message.Replace("'", "''");
				builder.Append('\'').Append(escaped).Append('\'');
				return builder.ToString();
			}
			catch {
				return null;
			}
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

