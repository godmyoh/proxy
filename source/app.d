import std.stdio;

import core.sys.windows.windows;
import core.sys.windows.winhttp;

import std.stdio;

void main()
{
    WINHTTP_CURRENT_USER_IE_PROXY_CONFIG ieProxyConfig;

    if (!WinHttpGetIEProxyConfigForCurrentUser(&ieProxyConfig))
    {
        printLastError();
        return;
    }
    
    writefln("IE/OS Settings:");
    writefln("  Auto Config Url = %s", ieProxyConfig.lpszAutoConfigUrl.asWstring());
    writefln("  Proxy           = %s", ieProxyConfig.lpszProxy.asWstring());
    writefln("  Proxy Bypass    = %s", ieProxyConfig.lpszProxyBypass.asWstring());

    free(ieProxyConfig.lpszProxy);
    free(ieProxyConfig.lpszProxyBypass);
    
    if (ieProxyConfig.lpszAutoConfigUrl !is null)
    {
        auto hInternet = WinHttpOpen("ProxyTool", WINHTTP_ACCESS_TYPE_NO_PROXY, null, null, 0);

        if (hInternet is null)
        {
            printLastError();
            return;
        }

        scope (exit) if (!WinHttpCloseHandle(hInternet)) printLastError();

        WINHTTP_AUTOPROXY_OPTIONS wao;
        wao.dwFlags = WINHTTP_AUTOPROXY_CONFIG_URL;
        wao.lpszAutoConfigUrl = ieProxyConfig.lpszAutoConfigUrl;
        
        WINHTTP_PROXY_INFO wpi;

        if (!WinHttpGetProxyForUrl(hInternet, "https://www.google.com/", &wao, &wpi))
        {
            printLastError();
            return;
        }
        
        writefln("Proxy Auto-Configuration:");
        writefln("  Proxy           = %s", wpi.lpszProxy.asWstring());
        writefln("  Proxy Bypass    = %s", wpi.lpszProxyBypass.asWstring());

        free(wpi.lpszProxy);
        free(wpi.lpszProxyBypass);
        free(ieProxyConfig.lpszAutoConfigUrl);
    }
}

void printLastError()
{
    auto error = GetLastError();
    writefln("ERROR(%d)", error);
}

void free(wchar* p)
{
    if (p !is null)
        GlobalFree(p);
}

size_t strlen(const(wchar)* p)
{
    size_t len = 0;
    while (*p++ != 0)
        len++;
    return len;
}

const(wchar)[] asWstring(const(wchar)* p)
{
    if (p is null)
        return null;
    return p[0..strlen(p)];
}
