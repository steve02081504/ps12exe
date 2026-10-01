// C# port of the selected 7-Zip Deflate encoder, compile-time only.
// Copyright (C) 1999-2026 Igor Pavlov; C# adaptation (C) 2026 ps12exe contributors.
// SPDX-License-Identifier: LGPL-2.1-or-later
// Upstream: https://github.com/ip7z/7zip/tree/0766b733fe3e06dd2a7f9a3cfbf2108ac73abd17
// Adaptations: managed arrays instead of pointers/streams, fixed Deflate32 maximum
// profile (9/258/15), portable Huffman sort, no COM, native code or host codec.
// LzFind.c and HuffEnc.c are public domain; remaining selected files are LGPL.
using System;
using System.IO;

namespace Ps12exe.Gzip.Internal
{
	internal sealed class DeflateEncoder
	{
		const int k_CodeValue_Len_Is_Literal_Flag = 1 << 15;
		const int kNumDivPassesMax = 10, kNumTables = 1 << 10;
		const int kFixedHuffmanCodeBlockSizeMax = 256, kDivideCodeBlockSizeMin = 128, kDivideBlockSizeMin = 64;
		const int kMaxUncompressedBlockSize = 65535, kMatchArraySize = 65535 * 10;
		const int kMatchArrayLimit = kMatchArraySize - 258 * 4 * 2;
		const int kNumOptsBase = 4096, kNumOpts = 4096 + 258;
		const int kBlockUncompressedSizeThreshold = 65535 - 258 - kNumOpts;
		const int kNoLiteralStatPrice = 11, kNoLenStatPrice = 11, kNoPosStatPrice = 6;
		const int kIfinityPrice = 0xFFFFFFF, MAX_HUF_LEN_12 = 12, kMaxLevelBitLength = 7;
		const int kMatchMinLen = 3, kMatchMaxLen = 258;
		const int kFixedMainTableSize = 288, kFixedDistTableSize = 32, kDistTableSize64 = 32;
		const int kSymbolEndOfBlock = 256, kSymbolMatch = 257, kMainTableSize = 286;
		const int kLevelTableSize = 19, kTableDirectLevels = 16;
		const int kTableLevelRepNumber = 16, kTableLevel0Number = 17, kTableLevel0Number2 = 18;
		const int kFinalBlockFieldSize = 1, kBlockTypeFieldSize = 2;
		const int kNumLenCodesFieldSize = 5, kNumDistCodesFieldSize = 5, kNumLevelCodesFieldSize = 4;
		const int kNumLitLenCodesMin = 257, kNumDistCodesMin = 1, kNumLevelCodesMin = 4;
		const int kLevelFieldSize = 3, kStoredBlockLengthFieldSize = 16;
		static readonly int[] kLenStart32 = { 0,  1,  2,  3,  4,  5,  6,  7,   8,   10,  12,  14,  16,  20, 24, 28,
											32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 255, 0,  0 };
		static readonly int[] kLenDirectBits32 = { 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
												3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0, 0, 0 };
		static readonly int[] kDistStart = { 0,    1,    2,    3,    4,    6,     8,     12,    16,    24,   32,
											48,   64,   96,   128,  192,  256,   384,   512,   768,   1024, 1536,
											2048, 3072, 4096, 6144, 8192, 12288, 16384, 24576, 32768, 49152 };
		static readonly int[] kDistDirectBits = { 0, 0, 0, 0, 1, 1, 2,  2,  3,  3,  4,  4,  5,  5,  6,  6,
												7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14 };
		static readonly int[] kLevelDirectBits = { 2, 3, 7 };
		static readonly int[] kCodeLengthAlphabetOrder = { 16, 17, 18, 0, 8,  7, 9,  6, 10, 5,
														11, 4,  12, 3, 13, 2, 14, 1, 15 };
		static readonly int[] g_LenSlots = new int[256], g_FastPos = new int[512];
		static DeflateEncoder()
		{
			for (int i = 0; i < 29; i++)
				for (int j = 0; j < (1 << kLenDirectBits32[i]); j++)
					g_LenSlots[kLenStart32[i] + j] = i;
			int c = 0;
			for (int slot = 0; slot < 18; slot++)
				for (int j = 0; j < (1 << kDistDirectBits[slot]); j++)
					g_FastPos[c++] = slot;
		}
		static int GetPosSlot(int pos)
		{
			int shift = pos < 512 ? 0 : 8;
			return g_FastPos[pos >> shift] + shift * 2;
		}

		struct IntSlice
		{
			readonly int[] data;
			readonly int offset;
			public IntSlice(int[] values, int start)
			{
				data = values;
				offset = start;
			}
			public int this[int i]
			{
				get
				{
					return data[offset + i];
				}
				set
				{
					data[offset + i] = value;
				}
			}
			public static implicit operator IntSlice(int[] data)
			{
				return new IntSlice(data, 0);
			}
			public static IntSlice operator +(IntSlice data, int offset)
			{
				return new IntSlice(data.data, data.offset + offset);
			}
		}
		struct CCodeValue
		{
			public int Len, Pos;
		}
		struct COptimal
		{
			public int Price, PosPrev, BackPrev;
		}
		class CLevels
		{
			public readonly int[] litLenLevels = new int[288], distLevels = new int[32];
			public void CopyLevels(CLevels source)
			{
				Array.Copy(source.litLenLevels, litLenLevels, 288);
				Array.Copy(source.distLevels, distLevels, 32);
			}
			public void SetFixedLevels()
			{
				for (int i = 0; i < 288; i++)
					litLenLevels[i] = i < 144 ? 8 : i < 256 ? 9 : i < 280 ? 7 : 8;
				for (int i = 0; i < 32; i++)
					distLevels[i] = 5;
			}
			public void InitStructures()
			{
				for (int i = 0; i < 288; i++)
					litLenLevels[i] = i < 256 ? 8 : i == 256 ? 13 : 5;
				for (int i = 0; i < 32; i++)
					distLevels[i] = 5;
			}
		}
		sealed class CTables : CLevels
		{
			public bool UseSubBlocks, StoreMode, StaticMode;
			public int BlockSizeRes, m_Pos;
		}
		readonly MatchFinder finder;
		readonly BitWriter m_OutStream = new BitWriter();
		readonly CCodeValue[] m_Values = new CCodeValue[65535];
		readonly int[] m_OnePosMatchesMemory = new int[kMatchArraySize];
		IntSlice m_MatchDistances;
		// Upstream normalizes 15 passes to 7 Huffman passes and 10 split levels.
		const int m_NumFastBytes = 258, m_NumPasses = 7, m_NumDivPasses = 10;
		readonly bool m_CheckStatic = true;
		const int m_ValueBlockSize = (7 << 10) + (1 << 12) * m_NumDivPasses;
		const int m_NumLenCombinations = 256;
		readonly int[] m_LenStart = kLenStart32, m_LenDirectBits = kLenDirectBits32;
		int m_Pos, m_NumLitLenLevels, m_NumDistLevels, m_NumLevelCodes, m_ValueIndex;
		readonly int[] m_LevelLevels = new int[19];
		bool m_SecondPass;
		int m_AdditionalOffset, m_OptimumEndIndex, m_OptimumCurrentIndex, BlockSizeRes;
		readonly int[] m_LiteralPrices = new int[256], m_LenPrices = new int[256], m_PosPrices = new int[32];
		readonly CLevels m_NewLevels = new CLevels();
		readonly int[] mainFreqs = new int[288], distFreqs = new int[32];
		readonly int[] mainCodes = new int[288], distCodes = new int[32], levelCodes = new int[19], levelLens = new int[19];
		readonly CTables[] m_Tables = new CTables[kNumTables];
		readonly COptimal[] m_Optimum = new COptimal[kNumOpts];
		readonly int[] distanceTmp = new int[kMatchMaxLen * 2 + 3];

		DeflateEncoder(byte[] data)
		{
			finder = new MatchFinder(data);
			for (int i = 0; i < m_Tables.Length; i++)
				m_Tables[i] = new CTables();
		}
		public static byte[] Encode(byte[] data)
		{
			if (data == null)
				throw new ArgumentNullException("data");
			return new DeflateEncoder(data).Encode();
		}
		byte[] Encode()
		{
			CTables t = m_Tables[1];
			t.InitStructures();
			do
			{
				t.BlockSizeRes = kBlockUncompressedSizeThreshold;
				m_SecondPass = false;
				GetBlockPrice(1, m_NumDivPasses);
				CodeBlock(1, finder.Available == 0);
			} while (finder.Available != 0);
			return m_OutStream.Finish();
		}
		void GetMatches()
		{
			m_MatchDistances = new IntSlice(m_OnePosMatchesMemory, m_Pos);
			if (m_SecondPass)
			{
				m_Pos += m_MatchDistances[0] + 1;
				return;
			}
			int count = finder.GetMatches(distanceTmp);
			m_MatchDistances[0] = count;
			for (int i = 0; i < count; i++)
				m_MatchDistances[i + 1] = distanceTmp[i];
			m_Pos += count + 1;
			m_AdditionalOffset++;
		}
		void MovePos(int num)
		{
			if (!m_SecondPass && num > 0)
			{
				finder.Skip(num);
				m_AdditionalOffset += num;
			}
		}

		int Backward(ref int backRes, int cur)
		{
			m_OptimumEndIndex = cur;
			int posMem = m_Optimum[cur].PosPrev;
			int backMem = m_Optimum[cur].BackPrev;
			do
			{
				int posPrev = posMem;
				int backCur = backMem;
				backMem = m_Optimum[posPrev].BackPrev;
				posMem = m_Optimum[posPrev].PosPrev;
				m_Optimum[posPrev].BackPrev = backCur;
				m_Optimum[posPrev].PosPrev = (int)cur;
				cur = posPrev;
			} while (cur > 0);
			backRes = m_Optimum[0].BackPrev;
			m_OptimumCurrentIndex = m_Optimum[0].PosPrev;
			return m_OptimumCurrentIndex;
		}

		int GetOptimal(ref int backRes)
		{
			if (m_OptimumEndIndex != m_OptimumCurrentIndex)
			{
				int len = m_Optimum[m_OptimumCurrentIndex].PosPrev - m_OptimumCurrentIndex;
				backRes = m_Optimum[m_OptimumCurrentIndex].BackPrev;
				m_OptimumCurrentIndex = m_Optimum[m_OptimumCurrentIndex].PosPrev;
				return len;
			}
			m_OptimumCurrentIndex = m_OptimumEndIndex = 0;

			GetMatches();

			int lenEnd;
			{
				int numDistancePairs = m_MatchDistances[0];
				if (numDistancePairs == 0)
					return 1;
				IntSlice matchDistances = m_MatchDistances + 1;
				lenEnd = matchDistances[numDistancePairs - 2];

				if (lenEnd > m_NumFastBytes)
				{
					backRes = matchDistances[numDistancePairs - 1];
					MovePos(lenEnd - 1);
					return lenEnd;
				}

				m_Optimum[1].Price = m_LiteralPrices[finder.Data[finder.Index - m_AdditionalOffset]];
				m_Optimum[1].PosPrev = 0;

				m_Optimum[2].Price = kIfinityPrice;
				m_Optimum[2].PosPrev = 1;

				int offs = 0;

				for (int i = kMatchMinLen; i <= lenEnd; i++)
				{
					int distance = matchDistances[offs + 1];
					m_Optimum[i].PosPrev = 0;
					m_Optimum[i].BackPrev = (int)distance;
					m_Optimum[i].Price = m_LenPrices[i - kMatchMinLen] + m_PosPrices[GetPosSlot(distance)];
					if (i == matchDistances[offs])
						offs += 2;
				}
			}

			int cur = 0;

			for (;;)
			{
				++cur;
				if (cur == lenEnd || cur == kNumOptsBase || m_Pos >= kMatchArrayLimit)
					return Backward(ref backRes, cur);
				GetMatches();
				IntSlice matchDistances = m_MatchDistances + 1;
				int numDistancePairs = m_MatchDistances[0];
				int newLen = 0;
				if (numDistancePairs != 0)
				{
					newLen = matchDistances[numDistancePairs - 2];
					if (newLen > m_NumFastBytes)
					{
						int len = Backward(ref backRes, cur);
						m_Optimum[cur].BackPrev = matchDistances[numDistancePairs - 1];
						m_OptimumEndIndex = cur + newLen;
						m_Optimum[cur].PosPrev = (int)m_OptimumEndIndex;
						MovePos(newLen - 1);
						return len;
					}
				}
				int curPrice = m_Optimum[cur].Price;
				{
					int curAnd1Price = curPrice + m_LiteralPrices[finder.Data[finder.Index + cur - m_AdditionalOffset]];
					int optimumIndex = cur + 1;
					if (curAnd1Price < m_Optimum[optimumIndex].Price)
					{
						m_Optimum[optimumIndex].Price = curAnd1Price;
						m_Optimum[optimumIndex].PosPrev = (int)cur;
					}
				}
				if (numDistancePairs == 0)
					continue;
				while (lenEnd < cur + newLen)
					m_Optimum[++lenEnd].Price = kIfinityPrice;
				int offs = 0;
				int distance = matchDistances[offs + 1];
				curPrice += m_PosPrices[GetPosSlot(distance)];
				for (int lenTest = kMatchMinLen;; lenTest++)
				{
					int curAndLenPrice = curPrice + m_LenPrices[lenTest - kMatchMinLen];
					int optimumIndex = cur + lenTest;
					if (curAndLenPrice < m_Optimum[optimumIndex].Price)
					{
						m_Optimum[optimumIndex].Price = curAndLenPrice;
						m_Optimum[optimumIndex].PosPrev = (int)cur;
						m_Optimum[optimumIndex].BackPrev = (int)distance;
					}
					if (lenTest == matchDistances[offs])
					{
						offs += 2;
						if (offs == numDistancePairs)
							break;
						curPrice -= m_PosPrices[GetPosSlot(distance)];
						distance = matchDistances[offs + 1];
						curPrice += m_PosPrices[GetPosSlot(distance)];
					}
				}
			}
		}

		void LevelTableDummy(int[] levels, int numLevels, IntSlice freqs)
		{
			int prevLen = 0xFF;
			int nextLen = levels[0];
			int count = 0;
			int maxCount = 7;
			int minCount = 4;

			if (nextLen == 0)
			{
				maxCount = 138;
				minCount = 3;
			}

			for (int n = 0; n < numLevels; n++)
			{
				int curLen = nextLen;
				nextLen = (n < numLevels - 1) ? levels[n + 1] : 0xFF;
				count++;
				if (count < maxCount && curLen == nextLen)
					continue;

				if (count < minCount)
					freqs[curLen] += (int)count;
				else if (curLen != 0)
				{
					if (curLen != prevLen)
					{
						freqs[curLen]++;
						count--;
					}
					freqs[kTableLevelRepNumber]++;
				}
				else if (count <= 10)
					freqs[kTableLevel0Number]++;
				else
					freqs[kTableLevel0Number2]++;

				count = 0;
				prevLen = curLen;

				if (nextLen == 0)
				{
					maxCount = 138;
					minCount = 3;
				}
				else if (curLen == nextLen)
				{
					maxCount = 6;
					minCount = 3;
				}
				else
				{
					maxCount = 7;
					minCount = 4;
				}
			}
		}

		void WriteBits(int value, int numBits)
		{
			m_OutStream.WriteBits(value, numBits);
		}

		void LevelTableCode(int[] levels, int numLevels, int[] lens, int[] codes)
		{
			int prevLen = 0xFF;
			int nextLen = levels[0];
			int count = 0;
			int maxCount = 7;
			int minCount = 4;

			if (nextLen == 0)
			{
				maxCount = 138;
				minCount = 3;
			}

			for (int n = 0; n < numLevels; n++)
			{
				int curLen = nextLen;
				nextLen = (n < numLevels - 1) ? levels[n + 1] : 0xFF;
				count++;
				if (count < maxCount && curLen == nextLen)
					continue;

				if (count < minCount)
					for (int i = 0; i < count; i++)
						WriteBits(codes[curLen], lens[curLen]);
				else if (curLen != 0)
				{
					if (curLen != prevLen)
					{
						WriteBits(codes[curLen], lens[curLen]);
						count--;
					}
					WriteBits(codes[kTableLevelRepNumber], lens[kTableLevelRepNumber]);
					WriteBits(count - 3, 2);
				}
				else if (count <= 10)
				{
					WriteBits(codes[kTableLevel0Number], lens[kTableLevel0Number]);
					WriteBits(count - 3, 3);
				}
				else
				{
					WriteBits(codes[kTableLevel0Number2], lens[kTableLevel0Number2]);
					WriteBits(count - 11, 7);
				}

				count = 0;
				prevLen = curLen;

				if (nextLen == 0)
				{
					maxCount = 138;
					minCount = 3;
				}
				else if (curLen == nextLen)
				{
					maxCount = 6;
					minCount = 3;
				}
				else
				{
					maxCount = 7;
					minCount = 4;
				}
			}
		}

		void MakeTables(int maxHuffLen)
		{
			Huffman_Generate(mainFreqs, mainCodes, m_NewLevels.litLenLevels, kFixedMainTableSize, maxHuffLen);
			Huffman_Generate(distFreqs, distCodes, m_NewLevels.distLevels, kDistTableSize64, maxHuffLen);
		}

		static int Huffman_GetPrice(IntSlice freqs, IntSlice lens, int num)
		{
			int price = 0;
			int i;
			for (i = 0; i < num; i++)
				price += lens[i] * freqs[i];
			return price;
		}

		static int Huffman_GetPrice_Spec(IntSlice freqs, int[] lens, int num, IntSlice extraBits, int extraBase)
		{
			return Huffman_GetPrice(freqs, lens, num) + Huffman_GetPrice(freqs + extraBase, extraBits, num - extraBase);
		}

		int GetLzBlockPrice()
		{
			return Huffman_GetPrice_Spec(mainFreqs, m_NewLevels.litLenLevels, kFixedMainTableSize, m_LenDirectBits,
										kSymbolMatch) +
				Huffman_GetPrice_Spec(distFreqs, m_NewLevels.distLevels, kDistTableSize64, kDistDirectBits, 0);
		}

		void TryBlock()
		{
			Array.Clear(mainFreqs, 0, mainFreqs.Length);
			Array.Clear(distFreqs, 0, distFreqs.Length);

			m_ValueIndex = 0;
			int blockSize = BlockSizeRes;
			BlockSizeRes = 0;
			for (;;)
			{
				if (m_OptimumCurrentIndex == m_OptimumEndIndex)
				{
					if (m_Pos >= kMatchArrayLimit || BlockSizeRes >= blockSize ||
						(!m_SecondPass && ((finder.Available == 0) || m_ValueIndex >= m_ValueBlockSize)))
						break;
				}
				int pos = 0;
				int len;
				len = GetOptimal(ref pos);
				int codeValueIndex = m_ValueIndex++;
				if (len >= kMatchMinLen)
				{
					int newLen = len - kMatchMinLen;
					m_Values[codeValueIndex].Len = (int)newLen;
					mainFreqs[kSymbolMatch + g_LenSlots[newLen]]++;
					m_Values[codeValueIndex].Pos = (int)pos;
					distFreqs[GetPosSlot(pos)]++;
				}
				else
				{
					int b = finder.Data[finder.Index - m_AdditionalOffset];
					mainFreqs[b]++;
					m_Values[codeValueIndex].Len = k_CodeValue_Len_Is_Literal_Flag;
					m_Values[codeValueIndex].Pos = (int)b;
				}
				m_AdditionalOffset -= len;
				BlockSizeRes += len;
			}
			mainFreqs[kSymbolEndOfBlock]++;
			m_AdditionalOffset += BlockSizeRes;
			m_SecondPass = true;
		}

		void SetPrices(CLevels levels)
		{
			int i;
			for (i = 0; i < 256; i++)
			{
				int price = levels.litLenLevels[i];
				m_LiteralPrices[i] = ((price != 0) ? price : kNoLiteralStatPrice);
			}

			for (i = 0; i < m_NumLenCombinations; i++)
			{
				int slot = g_LenSlots[i];
				int price = levels.litLenLevels[kSymbolMatch + slot];
				m_LenPrices[i] = (int)(((price != 0) ? price : kNoLenStatPrice) + m_LenDirectBits[slot]);
			}

			for (i = 0; i < kDistTableSize64; i++)
			{
				int price = levels.distLevels[i];
				m_PosPrices[i] = (int)(((price != 0) ? price : kNoPosStatPrice) + kDistDirectBits[i]);
			}
		}

		static void Huffman_ReverseBits(int[] codes, int[] lens, int num)
		{
			for (int i = 0; i < num; i++)
			{
				int x = codes[i], reverse = 0;
				for (int bit = 0; bit < lens[i]; bit++)
				{
					reverse = (reverse << 1) | (x & 1);
					x >>= 1;
				}
				codes[i] = reverse;
			}
		}
		void WriteBlock()
		{
			Huffman_ReverseBits(mainCodes, m_NewLevels.litLenLevels, kFixedMainTableSize);
			Huffman_ReverseBits(distCodes, m_NewLevels.distLevels, kDistTableSize64);
			for (int i = 0; i < m_ValueIndex; i++)
			{
				int len = m_Values[i].Len, dist = m_Values[i].Pos;
				if (len == k_CodeValue_Len_Is_Literal_Flag)
					WriteBits(mainCodes[dist], m_NewLevels.litLenLevels[dist]);
				else
				{
					int slot = g_LenSlots[len];
					WriteBits(mainCodes[kSymbolMatch + slot], m_NewLevels.litLenLevels[kSymbolMatch + slot]);
					WriteBits(len - m_LenStart[slot], m_LenDirectBits[slot]);
					int posSlot = GetPosSlot(dist);
					WriteBits(distCodes[posSlot], m_NewLevels.distLevels[posSlot]);
					WriteBits(dist - kDistStart[posSlot], kDistDirectBits[posSlot]);
				}
			}
			WriteBits(mainCodes[kSymbolEndOfBlock], m_NewLevels.litLenLevels[kSymbolEndOfBlock]);
		}
		static int GetStorePrice(int blockSize, int bitPosition)
		{
			int price = 0;
			do
			{
				int nextBitPosition = (bitPosition + kFinalBlockFieldSize + kBlockTypeFieldSize) & 7;
				int numBitsForAlign = nextBitPosition > 0 ? (8 - nextBitPosition) : 0;
				int curBlockSize = (blockSize < (1 << 16)) ? blockSize : (1 << 16) - 1;
				price += kFinalBlockFieldSize + kBlockTypeFieldSize + numBitsForAlign + (2 + 2) * 8 + curBlockSize * 8;
				bitPosition = 0;
				blockSize -= curBlockSize;
			} while (blockSize != 0);
			return price;
		}

		void WriteStoreBlock(int blockSize, int additionalOffset, bool finalBlock)
		{
			do
			{
				int curBlockSize = (blockSize < (1 << 16)) ? blockSize : (1 << 16) - 1;
				blockSize -= curBlockSize;
				WriteBits((finalBlock && (blockSize == 0) ? 1 : 0), kFinalBlockFieldSize);
				WriteBits(0, kBlockTypeFieldSize);
				m_OutStream.FlushByte();
				WriteBits((int)curBlockSize, kStoredBlockLengthFieldSize);
				WriteBits((int)~curBlockSize, kStoredBlockLengthFieldSize);
				int dataIndex = finder.Index - additionalOffset;
				for (int i = 0; i < curBlockSize; i++)
					m_OutStream.WriteByte(finder.Data[dataIndex + i]);
				additionalOffset -= curBlockSize;
			} while (blockSize != 0);
		}

		int TryDynBlock(int tableIndex, int numPasses)
		{
			CTables t = m_Tables[tableIndex];
			BlockSizeRes = t.BlockSizeRes;
			int posTemp = t.m_Pos;
			SetPrices(t);

			for (int p = 0; p < numPasses; p++)
			{
				m_Pos = posTemp;
				TryBlock();
				int numHuffBits = m_ValueIndex > 18000  ? MAX_HUF_LEN_12
								: m_ValueIndex > 7000 ? 11
								: m_ValueIndex > 2000 ? 10
														: 9;
				MakeTables(numHuffBits);
				SetPrices(m_NewLevels);
			}

			t.CopyLevels(m_NewLevels);

			m_NumLitLenLevels = kMainTableSize;
			while (m_NumLitLenLevels > kNumLitLenCodesMin && m_NewLevels.litLenLevels[m_NumLitLenLevels - 1] == 0)
				m_NumLitLenLevels--;

			m_NumDistLevels = kDistTableSize64;
			while (m_NumDistLevels > kNumDistCodesMin && m_NewLevels.distLevels[m_NumDistLevels - 1] == 0)
				m_NumDistLevels--;

			int[] levelFreqs = new int[kLevelTableSize];

			LevelTableDummy(m_NewLevels.litLenLevels, m_NumLitLenLevels, levelFreqs);
			LevelTableDummy(m_NewLevels.distLevels, m_NumDistLevels, levelFreqs);

			Huffman_Generate(levelFreqs, levelCodes, levelLens, kLevelTableSize, kMaxLevelBitLength);

			m_NumLevelCodes = kNumLevelCodesMin;
			for (int i = 0; i < kLevelTableSize; i++)
			{
				int level = levelLens[kCodeLengthAlphabetOrder[i]];
				if (level > 0 && i >= m_NumLevelCodes)
					m_NumLevelCodes = i + 1;
				m_LevelLevels[i] = level;
			}

			return GetLzBlockPrice() +
				Huffman_GetPrice_Spec(levelFreqs, levelLens, kLevelTableSize, kLevelDirectBits, kTableDirectLevels) +
				kNumLenCodesFieldSize + kNumDistCodesFieldSize + kNumLevelCodesFieldSize +
				m_NumLevelCodes * kLevelFieldSize + kFinalBlockFieldSize + kBlockTypeFieldSize;
		}

		int TryFixedBlock(int tableIndex)
		{
			CTables t = m_Tables[tableIndex];
			BlockSizeRes = t.BlockSizeRes;
			m_Pos = t.m_Pos;
			m_NewLevels.SetFixedLevels();
			SetPrices(m_NewLevels);
			TryBlock();
			return kFinalBlockFieldSize + kBlockTypeFieldSize + GetLzBlockPrice();
		}

		int GetBlockPrice(int tableIndex, int numDivPasses)
		{
			CTables t = m_Tables[tableIndex];
			t.StaticMode = false;
			int price = TryDynBlock(tableIndex, m_NumPasses);
			t.BlockSizeRes = BlockSizeRes;
			int numValues = m_ValueIndex;
			int posTemp = m_Pos;
			int additionalOffsetEnd = m_AdditionalOffset;

			if (m_CheckStatic && m_ValueIndex <= kFixedHuffmanCodeBlockSizeMax)
			{
				int fixedPrice = TryFixedBlock(tableIndex);
				t.StaticMode = (fixedPrice < price);
				if (t.StaticMode)
					price = fixedPrice;
			}

			int storePrice = GetStorePrice(BlockSizeRes, 0);
			t.StoreMode = (storePrice <= price);
			if (t.StoreMode)
				price = storePrice;

			t.UseSubBlocks = false;

			if (numDivPasses > 1 && numValues >= kDivideCodeBlockSizeMin)
			{
				CTables t0 = m_Tables[(tableIndex << 1)];
				t0.CopyLevels(t);
				t0.BlockSizeRes = t.BlockSizeRes >> 1;
				t0.m_Pos = t.m_Pos;
				int subPrice = GetBlockPrice((tableIndex << 1), numDivPasses - 1);

				int blockSize2 = t.BlockSizeRes - t0.BlockSizeRes;
				if (t0.BlockSizeRes >= kDivideBlockSizeMin && blockSize2 >= kDivideBlockSizeMin)
				{
					CTables t1 = m_Tables[(tableIndex << 1) + 1];
					t1.CopyLevels(t);
					t1.BlockSizeRes = blockSize2;
					t1.m_Pos = m_Pos;
					m_AdditionalOffset -= t0.BlockSizeRes;
					subPrice += GetBlockPrice((tableIndex << 1) + 1, numDivPasses - 1);
					t.UseSubBlocks = (subPrice < price);
					if (t.UseSubBlocks)
						price = subPrice;
				}
			}

			m_AdditionalOffset = additionalOffsetEnd;
			m_Pos = posTemp;
			return price;
		}

		void CodeBlock(int tableIndex, bool finalBlock)
		{
			CTables t = m_Tables[tableIndex];
			if (t.UseSubBlocks)
			{
				CodeBlock((tableIndex << 1), false);
				CodeBlock((tableIndex << 1) + 1, finalBlock);
			}
			else
			{
				if (t.StoreMode)
					WriteStoreBlock(t.BlockSizeRes, m_AdditionalOffset, finalBlock);
				else
				{
					WriteBits((finalBlock ? 1 : 0), kFinalBlockFieldSize);
					if (t.StaticMode)
					{
						WriteBits(1, kBlockTypeFieldSize);
						TryFixedBlock(tableIndex);
						int i;
						int kMaxStaticHuffLen = 9;
						for (i = 0; i < kFixedMainTableSize; i++)
							mainFreqs[i] = (int)1 << (kMaxStaticHuffLen - m_NewLevels.litLenLevels[i]);
						for (i = 0; i < kFixedDistTableSize; i++)
							distFreqs[i] = (int)1 << (kMaxStaticHuffLen - m_NewLevels.distLevels[i]);
						MakeTables(kMaxStaticHuffLen);
					}
					else
					{
						if (m_NumDivPasses > 1 || m_CheckStatic)
							TryDynBlock(tableIndex, 1);
						WriteBits(2, kBlockTypeFieldSize);
						WriteBits(m_NumLitLenLevels - kNumLitLenCodesMin, kNumLenCodesFieldSize);
						WriteBits(m_NumDistLevels - kNumDistCodesMin, kNumDistCodesFieldSize);
						WriteBits(m_NumLevelCodes - kNumLevelCodesMin, kNumLevelCodesFieldSize);

						for (int i = 0; i < m_NumLevelCodes; i++)
							WriteBits(m_LevelLevels[i], kLevelFieldSize);

						Huffman_ReverseBits(levelCodes, levelLens, kLevelTableSize);
						LevelTableCode(m_NewLevels.litLenLevels, m_NumLitLenLevels, levelLens, levelCodes);
						LevelTableCode(m_NewLevels.distLevels, m_NumDistLevels, levelLens, levelCodes);
					}
					WriteBlock();
				}
				m_AdditionalOffset -= t.BlockSizeRes;
			}
		}

		// Portable form of 7-Zip's public-domain HuffEnc.c. Packed frequencies
		// retain symbol ordering; equal-frequency leaves precede internal nodes.
		static void Huffman_Generate(IntSlice freqs, int[] p, int[] lens, int numSymbols, int maxLen)
		{
			const int MASK = 1023, FREQ_MASK = ~1023;
			Array.Clear(lens, 0, lens.Length);
			int num = 0;
			for (int i = 0; i < numSymbols; i++)
				if (freqs[i] != 0)
					p[num++] = i | (freqs[i] << 10);
			Array.Sort(p, 0, num);
			if (num <= 2)
			{
				int minCode = 0, maxCode = 1;
				if (num != 0)
				{
					maxCode = p[num - 1] & MASK;
					if (num == 2)
					{
						minCode = p[0] & MASK;
						if (minCode > maxCode)
						{
							int temp = minCode;
							minCode = maxCode;
							maxCode = temp;
						}
					}
					else if (maxCode == 0)
						maxCode++;
				}
				p[minCode] = 0;
				p[maxCode] = 1;
				lens[minCode] = lens[maxCode] = 1;
				return;
			}
			int[] lenCounters = new int[17];
			lenCounters[1] = 2;
			int fb = (p[1] & FREQ_MASK) + p[0], f = p[2] & FREQ_MASK;
			int pi = 2, e = 0, b = 0, n = num;
			for (;;)
			{
				int sum;
				e++;
				if (fb < f)
				{
					sum = fb & FREQ_MASK;
					p[b++] = (fb & MASK) | (e << 10);
					fb = p[b];
					if (b == e)
					{
						if (++pi == n)
							break;
						sum += f;
						fb = (fb & MASK) | sum;
						p[e] = fb;
						f = p[pi] & FREQ_MASK;
						continue;
					}
				}
				else if (++pi == n)
				{
					p[b++] = (fb & MASK) | (e << 10);
					break;
				}
				else
				{
					sum = f;
					f = p[pi] & FREQ_MASK;
				}
				if (fb < f)
				{
					sum = (sum + fb) & FREQ_MASK;
					p[b++] = (fb & MASK) | (e << 10);
					p[e] = (p[e] & MASK) | sum;
					fb = p[b];
				}
				else if (++pi == n)
					break;
				else
				{
					sum += f;
					f = p[pi] & FREQ_MASK;
					p[e] = (p[e] & MASK) | sum;
				}
			}
			n -= 2;
			p[n] &= MASK;
			if (n != b)
			{
				int parent = n;
				do
				{
					int len = (p[parent] >> 10) + 1;
					parent--;
					lenCounters[len] -= 2;
					lenCounters[len + 1] += 4;
					n -= 2;
					p[n] = (p[n] & MASK) | (len << 10);
					p[n + 1] = (p[n + 1] & MASK) | (len << 10);
				} while (n != b);
			}
			while (b != 0)
			{
				b--;
				int len = (p[p[b] >> 10] >> 10) + 1;
				p[b] = (p[b] & MASK) | (len << 10);
				if (len >= maxLen)
				{
					for (len = maxLen - 1; lenCounters[len] == 0; len--)
					{
					}
				}
				lenCounters[len]--;
				lenCounters[len + 1] += 2;
			}
			int sorted = 0;
			for (int len = maxLen; len != 0; len--)
				for (int k = 0; k < lenCounters[len]; k++)
					lens[p[sorted++] & MASK] = len;
			int[] codes = new int[17];
			int code = 0;
			for (int len = 0; len < 16; len++)
				codes[len + 1] = code = (code + lenCounters[len]) << 1;
			for (int i = 0; i < numSymbols; i++)
			{
				int len = lens[i];
				p[i] = codes[len]++;
			}
		}

		// Public-domain Bt3Zip match finder from LzFind.c, specialized to a complete
		// byte array, 32 KiB history, 258-byte matches and 145 tree search cycles.
		sealed class MatchFinder
		{
			const int Window = 32769;
			public readonly byte[] Data;
			public int Index;
			public int Available
			{
				get {
					return Data.Length - Index;
				}
			}
			readonly int[] hash = new int[65536], son = new int[Window * 2];
			static readonly uint[] crc = CreateCrc();
			static uint[] CreateCrc()
			{
				uint[] values = new uint[256];
				for (uint i = 0; i < 256; i++)
				{
					uint r = i;
					for (int bit = 0; bit < 8; bit++)
						r = (r >> 1) ^ ((r & 1) != 0 ? 0xedb88320U : 0);
					values[i] = r;
				}
				return values;
			}
			public MatchFinder(byte[] data)
			{
				Data = data;
			}
			public int GetMatches(int[] distances)
			{
				return Find(distances);
			}
			public void Skip(int count)
			{
				while (count-- != 0)
					Find(null);
			}
			int Find(int[] distances)
			{
				int limit = Math.Min(258, Available);
				if (limit < 3)
				{
					Index++;
					return 0;
				}
				int pos = Index + 1, cyclic = pos % Window;
				int hv = (int)(((uint)Data[Index + 2] | ((uint)Data[Index] << 8)) ^ crc[Data[Index + 1]]) & 65535;
				int curMatch = hash[hv];
				hash[hv] = pos;
				int ptr0 = cyclic * 2 + 1, ptr1 = cyclic * 2;
				int len0 = 0, len1 = 0, maxLen = 2, count = 0;
				int minPosition = Math.Max(0, pos - Window), cycles = 145;
				while (curMatch > minPosition)
				{
					int delta = pos - curMatch;
					int pair = (cyclic - delta + (cyclic < delta ? Window : 0)) * 2;
					int previous = Index - delta, len = Math.Min(len0, len1);
					int pair0 = son[pair];
					if (Data[previous + len] == Data[Index + len])
					{
						while (++len != limit && Data[previous + len] == Data[Index + len])
						{
						}
						if (maxLen < len)
						{
							maxLen = len;
							if (distances != null)
							{
								distances[count++] = len;
								distances[count++] = delta - 1;
							}
							if (len == limit)
							{
								son[ptr1] = pair0;
								son[ptr0] = son[pair + 1];
								Index++;
								return count;
							}
						}
					}
					if (Data[previous + len] < Data[Index + len])
					{
						son[ptr1] = curMatch;
						curMatch = son[pair + 1];
						ptr1 = pair + 1;
						len1 = len;
					}
					else
					{
						son[ptr0] = curMatch;
						curMatch = pair0;
						ptr0 = pair;
						len0 = len;
					}
					if (--cycles == 0)
						break;
				}
				son[ptr0] = son[ptr1] = 0;
				Index++;
				return count;
			}
		}
		sealed class BitWriter
		{
			readonly MemoryStream output = new MemoryStream();
			uint bits;
			int count;
			public void WriteBits(int value, int length)
			{
				bits |= ((uint)value & ((1U << length) - 1)) << count;
				count += length;
				while (count >= 8)
				{
					output.WriteByte((byte)bits);
					bits >>= 8;
					count -= 8;
				}
			}
			public void FlushByte()
			{
				if (count != 0)
					output.WriteByte((byte)bits);
				bits = 0;
				count = 0;
			}
			public void WriteByte(byte value)
			{
				output.WriteByte(value);
			}
			public byte[] Finish()
			{
				FlushByte();
				byte[] result = output.ToArray();
				output.Dispose();
				return result;
			}
		}
	}
}
