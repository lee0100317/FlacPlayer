//
//  FlacDecompress.cpp
//  FlacPlayer
//
//  Created by hao.li on 13-4-10.
//  Copyright (c) 2013年 buct. All rights reserved.
//

#include "FlacDecompress.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

extern "C"
{
#include "share/grabbag/replaygain.h"
}

#ifndef min
#define min(a,b)  (((a)<(b))?(a):(b))
#endif

#pragma mark - callback declare

static FLAC__StreamDecoderWriteStatus write_callback(const FLAC__StreamDecoder *decoder, const FLAC__Frame *frame, const FLAC__int32 * const buffer[], void *client_data);
static void metadata_callback(const FLAC__StreamDecoder *decoder, const FLAC__StreamMetadata *metadata, void *client_data);
static void error_callback(const FLAC__StreamDecoder *decoder, FLAC__StreamDecoderErrorStatus status, void *client_data);

#pragma mark - callback redirect

static FLAC__StreamDecoderWriteStatus write_callback(const FLAC__StreamDecoder *decoder, const FLAC__Frame *frame, const FLAC__int32 * const buffer[], void *client_data)
{
    ClFlacDecompress *pDecompress = static_cast<ClFlacDecompress *>(client_data);
    return pDecompress->Write_callback(decoder, frame, buffer, client_data);
}

static void metadata_callback(const FLAC__StreamDecoder *decoder, const FLAC__StreamMetadata *metadata, void *client_data)
{
    if (metadata->type == FLAC__METADATA_TYPE_STREAMINFO)
    {
        unsigned long long total_samples = metadata->data.stream_info.total_samples;
        unsigned int sample_rate = metadata->data.stream_info.sample_rate;
        unsigned int channels = metadata->data.stream_info.channels;
        unsigned int    bps = metadata->data.stream_info.bits_per_sample;
        unsigned int frameSize = metadata->data.stream_info.max_framesize;
        unsigned int blockSize = metadata->data.stream_info.max_blocksize;
        fprintf(stderr, "sample rate    : %u Hz\n", sample_rate);
        fprintf(stderr, "channels       : %u\n", channels);
        fprintf(stderr, "bits per sample: %u\n", bps);
        fprintf(stderr, "MaxframeSize   : %u\n", frameSize);
        fprintf(stderr, "Max BlockSize  : %u\n", blockSize);
        fprintf(stderr, "total samples  : %llu\n", total_samples);
    }
    else if (metadata->type == FLAC__METADATA_TYPE_STREAMINFO)
    {
        double  reference, gain, peak;
        FLAC__bool album_mode = false;
        if (grabbag__replaygain_load_from_vorbiscomment(metadata, album_mode, false, &reference, &gain, &peak)) {
            fprintf(stderr, "has replaygain    : yes");
        } else {
            fprintf(stderr, "has replaygain    : no");
        }
    }

    
    ClFlacDecompress *pDecompress = static_cast<ClFlacDecompress *>(client_data);
    pDecompress->Metadata_callback(decoder, metadata, client_data);
}

static void error_callback(const FLAC__StreamDecoder *decoder, FLAC__StreamDecoderErrorStatus status, void *client_data)
{
    ClFlacDecompress *pDecompress = static_cast<ClFlacDecompress *>(client_data);
    pDecompress->Error_callback(decoder, status, client_data);
}

#pragma mark - class define

ClFlacDecompress::ClFlacDecompress()
    :m_Decoder(NULL),
     m_Total_samples(0),
     m_Sample_rate(0),
     m_nChannels(0),
     m_Bps(0),
     m_nSamplesInBuffer(0),
     m_bAbortFlag(false)
{
	if((m_Decoder = FLAC__stream_decoder_new()) == NULL) {
		fprintf(stderr, "ERROR: allocating decoder\n");
	}
//    bzero(m_Buffer_[0], FLAC__MAX_BLOCK_SIZE * 2);
//    bzero(m_Buffer_[1], FLAC__MAX_BLOCK_SIZE * 2);

}

ClFlacDecompress::~ClFlacDecompress()
{
    if (m_Decoder) {
        FLAC__stream_decoder_finish(m_Decoder);
        FLAC__stream_decoder_delete(m_Decoder);
        m_Decoder = NULL;
    }
}

bool ClFlacDecompress::InitializeDecompressor(const char *file)
{
    if (m_Decoder == NULL || file == NULL || strlen(file) == 0) {
        return false;
    }
    
    if (FLAC__stream_decoder_get_state(m_Decoder) != FLAC__STREAM_DECODER_UNINITIALIZED) {
        FLAC__stream_decoder_finish(m_Decoder);
    }
    
    FLAC__stream_decoder_set_md5_checking(m_Decoder, false);
    FLAC__stream_decoder_set_metadata_ignore_all(m_Decoder);
    FLAC__stream_decoder_set_metadata_respond(m_Decoder, FLAC__METADATA_TYPE_VORBIS_COMMENT);
    FLAC__stream_decoder_set_metadata_respond(m_Decoder, FLAC__METADATA_TYPE_STREAMINFO);
    
    if (FLAC__STREAM_DECODER_INIT_STATUS_OK != FLAC__stream_decoder_init_file(m_Decoder,
                                                                              file,
                                                                              write_callback,
                                                                              metadata_callback,
                                                                              error_callback,
                                                                              this))
    {
        fprintf(stderr, "error: %s", FLAC__stream_decoder_get_resolved_state_string(m_Decoder));
        return false;
    }
    
    //Init 
    
    m_bAbortFlag = false;
    m_Bps = 0;
    m_nChannels = 0;
    m_nSamplesInBuffer = 0;
    m_Total_samples = 0;
    m_Sample_rate = 0;
    
    if (false == FLAC__stream_decoder_process_until_end_of_metadata(m_Decoder))
    {
        return false;
    }

    return true;
}

void ClFlacDecompress::UnInitializeDecompressor()
{
    if (m_Decoder && FLAC__stream_decoder_get_state(m_Decoder) != FLAC__STREAM_DECODER_UNINITIALIZED) {
        FLAC__stream_decoder_finish(m_Decoder);
    }
}

#pragma mark - main funcs

int ClFlacDecompress::GetData(char * pBuffer, int nBlocks, int * pBlocksRetrieved)
{
    while (m_nSamplesInBuffer < nBlocks) {
        if (FLAC__stream_decoder_get_state(m_Decoder) == (FLAC__STREAM_DECODER_END_OF_STREAM))
        {
            break;
        }
        else if (!FLAC__stream_decoder_process_single(m_Decoder))
        {
            break;
        }
        
    }
    const unsigned retriveBlockCnt = min(m_nSamplesInBuffer, nBlocks);
    FLAC__byte *pWriter = (FLAC__byte *) pBuffer;
    int incr = m_Bps / 8 * m_nChannels;
    for (int sampleIdx=0; sampleIdx<retriveBlockCnt; sampleIdx++) {
        switch (m_Bps) {
            case 8:
                for (int ch=0; ch<m_nChannels; ch++)
                {
                    pWriter[0] = m_Buffer[ch][sampleIdx] ^ 0x80;
                }
                break;
            case 24:
                for (int ch=0; ch<m_nChannels; ch++)
                {
                    pWriter[2] = (FLAC__byte) (m_Buffer[ch][sampleIdx] >> 16);
                }
            case 16:
                for (int ch=0; ch<m_nChannels; ch++)
                {
                    pWriter[0] = (FLAC__byte) (m_Buffer[ch][sampleIdx]);
                    pWriter[1] = (FLAC__byte) (m_Buffer[ch][sampleIdx] >> 8);
                }
                break;
            default:
                break;
        }
        pWriter += incr;
    }
    m_nSamplesInBuffer -= retriveBlockCnt;
    for (int ch=0; ch<m_nChannels; ch++) {
        memmove(&m_Buffer[ch][0], &m_Buffer[ch][retriveBlockCnt], sizeof(m_Buffer[0][0]) * retriveBlockCnt);
    }
    
    *pBlocksRetrieved = retriveBlockCnt;
    
    return 0;
}

int ClFlacDecompress::Seek(int nBlockOffset)
{
    m_nSamplesInBuffer = 0;
    if (!FLAC__stream_decoder_seek_absolute(m_Decoder, nBlockOffset)) {
        if (FLAC__stream_decoder_get_state(m_Decoder) == FLAC__STREAM_DECODER_SEEK_ERROR) {
            FLAC__stream_decoder_flush(m_Decoder);
            FLAC__stream_decoder_seek_absolute (m_Decoder, 0);
        }
    }
    return 0;
}

int ClFlacDecompress::GetInfo(DECOMPRESS_FIELDS Field, int nParam1, int nParam2)
{
    int nRetVal = 0;
    switch (Field)
    {
        case APE_INFO_SAMPLE_RATE:
            nRetVal = m_Sample_rate;
            break;
        case APE_INFO_CHANNELS:
            nRetVal = m_nChannels;
            break;
        case APE_INFO_BITS_PER_SAMPLE:
            nRetVal = m_Bps;
            break;
        case APE_INFO_TOTAL_BLOCKS:
            nRetVal = m_Total_samples;
            break;
        case APE_INFO_BLOCK_ALIGN:
            nRetVal = m_Bps / 8;
            break;
        case APE_INFO_BYTES_PER_SAMPLE:
            nRetVal = m_Bps / 8;
            break;
        default:
            break;
    }
    return nRetVal;
}

#pragma mark - callback

FLAC__StreamDecoderWriteStatus ClFlacDecompress::Write_callback(const FLAC__StreamDecoder *decoder, const FLAC__Frame *frame, const FLAC__int32 * const buffer[], void *client_data)
//写入缓存空间
{
    const unsigned samplesCnt = frame->header.blocksize;
    if (m_bAbortFlag) {
        return FLAC__STREAM_DECODER_WRITE_STATUS_ABORT;
    }
    for (unsigned channel=0; channel<m_nChannels; channel++) {
        memcpy(&m_Buffer[channel][m_nSamplesInBuffer], buffer[channel], sizeof(buffer[0][0]) * samplesCnt);
    }
    m_nSamplesInBuffer += samplesCnt;
    return FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE;
}

void ClFlacDecompress::Metadata_callback(const FLAC__StreamDecoder *decoder, const FLAC__StreamMetadata *metadata, void *client_data)
{
    if (metadata->type == FLAC__METADATA_TYPE_STREAMINFO) {
        m_Total_samples = metadata->data.stream_info.total_samples;
        m_Bps = metadata->data.stream_info.bits_per_sample;
        m_nChannels = metadata->data.stream_info.channels;
        m_Sample_rate = metadata->data.stream_info.sample_rate;
    }
    
    if (m_Bps != 8 && m_Bps != 16 && m_Bps != 24) {
        m_bAbortFlag = true;
        return;
    }
}

void ClFlacDecompress::Error_callback(const FLAC__StreamDecoder *decoder, FLAC__StreamDecoderErrorStatus status, void *client_data)
{
    if (status != FLAC__STREAM_DECODER_ERROR_STATUS_LOST_SYNC) {
        m_bAbortFlag = true;
    }
}
