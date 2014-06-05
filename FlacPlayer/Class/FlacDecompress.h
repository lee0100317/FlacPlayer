//
//  FlacDecompress.h
//  FlacPlayer
//
//  Created by hao.li on 13-4-10.
//  Copyright (c) 2013年 buct. All rights reserved.
//

#ifndef __FlacPlayer__FlacDecompress__
#define __FlacPlayer__FlacDecompress__

#include "FLAC/stream_decoder.h"

#define FLAC_MAX_SUPPORT_CHANNELS 2

enum DECOMPRESS_FIELDS
{
    APE_INFO_FILE_VERSION = 1000,               // version of the APE file * 1000 (3.93 = 3930) [ignored, ignored]
    APE_INFO_COMPRESSION_LEVEL = 1001,          // compression level of the APE file [ignored, ignored]
    APE_INFO_FORMAT_FLAGS = 1002,               // format flags of the APE file [ignored, ignored]
    APE_INFO_SAMPLE_RATE = 1003,                // sample rate (Hz) [ignored, ignored]
    APE_INFO_BITS_PER_SAMPLE = 1004,            // bits per sample [ignored, ignored]
    APE_INFO_BYTES_PER_SAMPLE = 1005,           // number of bytes per sample [ignored, ignored]
    APE_INFO_CHANNELS = 1006,                   // channels [ignored, ignored]
    APE_INFO_BLOCK_ALIGN = 1007,                // block alignment [ignored, ignored]
    APE_INFO_BLOCKS_PER_FRAME = 1008,           // number of blocks in a frame (frames are used internally)  [ignored, ignored]
    APE_INFO_FINAL_FRAME_BLOCKS = 1009,         // blocks in the final frame (frames are used internally) [ignored, ignored]
    APE_INFO_TOTAL_FRAMES = 1010,               // total number frames (frames are used internally) [ignored, ignored]
    APE_INFO_WAV_HEADER_BYTES = 1011,           // header bytes of the decompressed WAV [ignored, ignored]
    APE_INFO_WAV_TERMINATING_BYTES = 1012,      // terminating bytes of the decompressed WAV [ignored, ignored]
    APE_INFO_WAV_DATA_BYTES = 1013,             // data bytes of the decompressed WAV [ignored, ignored]
    APE_INFO_WAV_TOTAL_BYTES = 1014,            // total bytes of the decompressed WAV [ignored, ignored]
    APE_INFO_APE_TOTAL_BYTES = 1015,            // total bytes of the APE file [ignored, ignored]
    APE_INFO_TOTAL_BLOCKS = 1016,               // total blocks of audio data [ignored, ignored]
    APE_INFO_LENGTH_MS = 1017,                  // length in ms (1 sec = 1000 ms) [ignored, ignored]
    APE_INFO_AVERAGE_BITRATE = 1018,            // average bitrate of the APE [ignored, ignored]
    APE_INFO_FRAME_BITRATE = 1019,              // bitrate of specified APE frame [frame index, ignored]
    APE_INFO_DECOMPRESSED_BITRATE = 1020,       // bitrate of the decompressed WAV [ignored, ignored]
    APE_INFO_PEAK_LEVEL = 1021,                 // peak audio level (obsolete) (-1 is unknown) [ignored, ignored]
    APE_INFO_SEEK_BIT = 1022,                   // bit offset [frame index, ignored]
    APE_INFO_SEEK_BYTE = 1023,                  // byte offset [frame index, ignored]
    APE_INFO_WAV_HEADER_DATA = 1024,            // error code [buffer *, max bytes]
    APE_INFO_WAV_TERMINATING_DATA = 1025,       // error code [buffer *, max bytes]
    APE_INFO_WAVEFORMATEX = 1026,               // error code [waveformatex *, ignored]
    APE_INFO_IO_SOURCE = 1027,                  // I/O source (CIO *) [ignored, ignored]
    APE_INFO_FRAME_BYTES = 1028,                // bytes (compressed) of the frame [frame index, ignored]
    APE_INFO_FRAME_BLOCKS = 1029,               // blocks in a given frame [frame index, ignored]
    APE_INFO_TAG = 1030,                        // point to tag (CAPETag *) [ignored, ignored]
    
    APE_DECOMPRESS_CURRENT_BLOCK = 2000,        // current block location [ignored, ignored]
    APE_DECOMPRESS_CURRENT_MS = 2001,           // current millisecond location [ignored, ignored]
    APE_DECOMPRESS_TOTAL_BLOCKS = 2002,         // total blocks in the decompressors range [ignored, ignored]
    APE_DECOMPRESS_LENGTH_MS = 2003,            // length of the decompressors range in milliseconds [ignored, ignored]
    APE_DECOMPRESS_CURRENT_BITRATE = 2004,      // current bitrate [ignored, ignored]
    APE_DECOMPRESS_AVERAGE_BITRATE = 2005,      // average bitrate (works with ranges) [ignored, ignored]
    
    APE_INTERNAL_INFO = 3000,                   // for internal use -- don't use (returns APE_FILE_INFO *) [ignored, ignored]
};

class ClFlacDecompress
{
public:
    
    ClFlacDecompress();
    virtual ~ClFlacDecompress();
    
    //main funcs
    
    virtual int GetData(char * pBuffer, int nBlocks, int * pBlocksRetrieved);
    virtual int Seek(int nBlockOffset);
    virtual int GetInfo(DECOMPRESS_FIELDS Field, int nParam1 = 0, int nParam2 = 0);
    
    // for callback
    
    FLAC__StreamDecoderWriteStatus Write_callback(const FLAC__StreamDecoder *decoder, const FLAC__Frame *frame, const FLAC__int32 * const buffer[], void *client_data);
    void Metadata_callback(const FLAC__StreamDecoder *decoder, const FLAC__StreamMetadata *metadata, void *client_data);
    void Error_callback(const FLAC__StreamDecoder *decoder, FLAC__StreamDecoderErrorStatus status, void *client_data);
    
    bool InitializeDecompressor(const char *file);
    void UnInitializeDecompressor();
    
protected:
    
    //Data
    
    FLAC__StreamDecoder *m_Decoder;
    FLAC__uint64 m_Total_samples;
    unsigned m_Sample_rate;
    unsigned m_nChannels;
    unsigned m_Bps;
    
    //buffer 
    FLAC__int32 m_Buffer[FLAC_MAX_SUPPORT_CHANNELS][FLAC__MAX_BLOCK_SIZE * 2];
    FLAC__int32 *m_Buffer_[FLAC_MAX_SUPPORT_CHANNELS] = { m_Buffer[0], m_Buffer[1] };
    unsigned m_nSamplesInBuffer;
    FLAC__bool m_bAbortFlag;
};



#endif /* defined(__FlacPlayer__FlacDecompress__) */
