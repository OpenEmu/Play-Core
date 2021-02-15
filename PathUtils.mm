// Copyright (c) 2021, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import <Foundation/Foundation.h>
#import "PureiGameCore.h"
#include "PathUtils.h"
#include "Utf8.h"

using namespace Framework;

fs::path PathUtils::GetRoamingDataPath()
{
    __strong __typeof__(_current) current = _current;
    if (current == nil) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        std::string directory = [[paths objectAtIndex: 0] fileSystemRepresentation];
        return fs::path(directory);
    }
    NSString *path = current.supportDirectoryPath;
    return fs::path(path.fileSystemRepresentation);
}

fs::path PathUtils::GetAppResourcesPath()
{
    NSBundle* bundle = [NSBundle bundleForClass:[PureiGameCore class]];
    NSString* bundlePath = [bundle resourcePath];
    return fs::path([bundlePath fileSystemRepresentation]);
}

fs::path PathUtils::GetPersonalDataPath()
{
    return GetRoamingDataPath();
}

fs::path PathUtils::GetCachePath()
{
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    std::string directory = [[paths objectAtIndex: 0] fileSystemRepresentation];
    return fs::path(directory);
}

void PathUtils::EnsurePathExists(const fs::path& path)
{
    typedef fs::path PathType;
    PathType buildPath;
    for(PathType::iterator pathIterator(path.begin());
        pathIterator != path.end(); pathIterator++)
    {
        buildPath /= (*pathIterator);
        std::error_code existsErrorCode;
        bool exists = fs::exists(buildPath, existsErrorCode);
        if(existsErrorCode)
        {
            if(existsErrorCode.value() == ENOENT)
            {
                exists = false;
            }
            else
            {
                throw std::runtime_error("Couldn't ensure that path exists.");
            }
        }
        if(!exists)
        {
            fs::create_directory(buildPath);
        }
    }
}

////////////////////////////////////////////
//NativeString <-> Path Function Utils
////////////////////////////////////////////

template <typename StringType>
static std::string GetNativeStringFromPathInternal(const StringType&);

template <>
std::string GetNativeStringFromPathInternal(const std::string& str)
{
    return str;
}

template <typename StringType>
static StringType GetPathFromNativeStringInternal(const std::string&);

template <>
std::string GetPathFromNativeStringInternal(const std::string& str)
{
    return str;
}

////////////////////////////////////////////
//NativeString <-> Path Function Implementations
////////////////////////////////////////////

std::string PathUtils::GetNativeStringFromPath(const fs::path& path)
{
    return GetNativeStringFromPathInternal(path.native());
}

fs::path PathUtils::GetPathFromNativeString(const std::string& str)
{
    auto cvtStr = GetPathFromNativeStringInternal<fs::path::string_type>(str);
    return fs::path(cvtStr);
}
