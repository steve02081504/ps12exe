using System;
using System.IO;
using Ps12exe.Gzip.Internal;

// Compile-time only: managed 7-Zip Deflate port with a fixed gzip container.
public static class GzipPackCodec
{
	private static readonly uint[] CrcTable = CreateCrcTable();
	private static uint[] CreateCrcTable()
	{
		uint[] table = new uint[256];
		for (uint i = 0; i < 256; i++)
		{
			uint crc = i;
			for (int bit = 0; bit < 8; bit++)
				crc = (crc >> 1) ^ ((crc & 1) != 0 ? 0xedb88320U : 0U);
			table[i] = crc;
		}
		return table;
	}
	public static byte[] Compress(byte[] data)
	{
		if (data == null) throw new ArgumentNullException("data");
		byte[] body = DeflateEncoder.Encode(data);
		using (MemoryStream output = new MemoryStream())
		{
			// MTIME=0, no filename, XFL=2, OS=255.
			byte[] header = {31,139,8,0,0,0,0,0,2,255};
			output.Write(header, 0, header.Length);
			output.Write(body, 0, body.Length);
			uint crc = 0xffffffffU;
			for (int i = 0; i < data.Length; i++)
				crc = CrcTable[(crc ^ data[i]) & 255] ^ (crc >> 8);
			using (BinaryWriter trailer = new BinaryWriter(output))
			{
				trailer.Write(crc ^ 0xffffffffU);
				trailer.Write((uint)data.Length);
				return output.ToArray();
			}
		}
	}
}
