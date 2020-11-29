module app;

import core.sys.windows.windows;
import core.sys.windows.winhttp;
import core.sys.windows.wininet; // locally modified

import std.array;
import std.conv;
import std.getopt;
import std.stdio;

enum ProxyType
{
    nop,
    none,
    pac,
}

void main(string[] args)
{
    ProxyType type;
    string pac;
    bool removePacUrl;

    try
    {
        auto result = getopt(args,
                             "set-type", "[string] none|pac", &type,
                             "set-pac-url", "[string] Set proxy auto-configuration file setting.", &pac,
                             "remove-pac-url", "[bool] Empty proxy auto-configuration file setting.", &removePacUrl);

        if (result.helpWanted)
        {
            defaultGetoptPrinter("proxy [OPTIONS]", result.options);
            return;
        }

        if (args.length > 1)
        {
            defaultGetoptPrinter("ERROR: Invalid parameter " ~ args[1], result.options);
            return;
        }
    }
    catch (GetOptException e)
    {
        writefln("ERROR: %s", e.msg);
        return;
    }

    bool hasOption()
    {
        if (type != ProxyType.nop) return true;
        if (!pac.empty) return true;
        if (removePacUrl) return true;

        return false;
    }

    if (hasOption())
    {
        INTERNET_PER_CONN_OPTIONW[] pacOptions;
        if (type != ProxyType.nop)
        {
            INTERNET_PER_CONN_OPTIONW option;
            option.dwOption = INTERNET_PER_CONN_FLAGS;
            final switch (type) with (ProxyType)
            {
                case nop:  assert(false);
                case none: option.dwValue = PROXY_TYPE_DIRECT; break;
                case pac:  option.dwValue = PROXY_TYPE_AUTO_PROXY_URL; break;
            }
            pacOptions ~= option;
        }

        if (!pac.empty)
        {
            INTERNET_PER_CONN_OPTIONW option;
            option.dwOption = INTERNET_PER_CONN_AUTOCONFIG_URL;
            option.pszValue = (pac ~ "\0").to!wstring.dup.ptr;
            pacOptions ~= option;
        }

        if (removePacUrl)
        {
            INTERNET_PER_CONN_OPTIONW option;
            option.dwOption = INTERNET_PER_CONN_AUTOCONFIG_URL;
            option.pszValue = cast(wchar*)(""w.ptr);
            pacOptions ~= option;
        }

        INTERNET_PER_CONN_OPTION_LISTW optionList;
        with (optionList)
        {
            dwSize = INTERNET_PER_CONN_OPTION_LISTW.sizeof;
            pszConnection = null;
            dwOptionCount = cast(uint)pacOptions.length;
            pOptions = pacOptions.ptr;
        }

        if (!InternetSetOptionW(null, INTERNET_OPTION_PER_CONNECTION_OPTION, &optionList, INTERNET_PER_CONN_OPTION_LISTW.sizeof))
        {
            printLastError();
            return;
        }

        InternetSetOptionW(null, INTERNET_OPTION_SETTINGS_CHANGED, null, 0);
        InternetSetOptionW(null, INTERNET_OPTION_REFRESH, null, 0);

        return;
    }
    else
    {
        show();
    }
}

void show()
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
