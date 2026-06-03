module api.dn.chans.chan_ssl_context;

import openssl_libs : SSL, BIO, SSL_shutdown, SSL_free, BIO_reset, SSL_clear;

/**
 * Authors: initkfs
 */
struct ChanSSLContext
{
    SSL* ssl;
    BIO* rbio;
    BIO* wbio;
    bool isInitSSL;
    bool isOpen;

    void clear()
    {
        ssl = null;
        rbio = null;
        wbio = null;
        isInitSSL = false;
        isOpen = false;
    }

    void shutdown()
    {
        if (ssl)
        {
            SSL_shutdown(ssl);
        }
    }

    void close()
    {
        if (!isOpen && !isInitSSL)
        {
            return;
        }

        if (ssl)
        {
            SSL_clear(ssl);
        }

        resetbio;
        isOpen = false;
        isInitSSL = false;
    }

    void resetbio()
    {
        if (rbio)
        {
            BIO_reset(rbio);
        }

        if (wbio)
        {
            BIO_reset(wbio);
        }
    }

    void freeSSL()
    {
        if (ssl)
        {
            SSL_free(ssl);
            ssl = null;
        }
    }

    void reset()
    {
        if (ssl)
        {
            //TODO errror code == -1
            SSL_clear(ssl);
        }

        resetbio;
        isOpen = false;
        isInitSSL = false;
    }
}