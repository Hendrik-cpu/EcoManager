do
    local oldDiskGetFileInfo = DiskGetFileInfo
    local UIFileCache = {}
    local FileCache = {}

    function DiskGetFileInfo(file)
        if(not FileCache[file]) then
            FileCache[file] = oldDiskGetFileInfo(file)
        end
                
        return FileCache[file]
    end

    --* given a path and name relative to the skin path, returns the full path based on the current skin
    function UIFile(filespec)
        local skins = import('/lua/skins/skins.lua').skins
        local skin = currentSkin()
        local currentPath = skins[skin].texturesPath

        if skin == nil or currentPath == nil then
            return nil
        end

        if(not UIFileCache[skin][filespec])  then
            local found = false

            if skin == 'default' then
                -- if current skin is default, then don't bother trying to look for it, just append the default dir
                found = currentPath .. filespec
            else
                local nextSkin = skin

                while not found and nextSkin do
                    local curFile = currentPath .. filespec

                    if DiskGetFileInfo(curFile) then
                        found = curFile
                    else
                        nextSkin = skins[nextSkin].default
                        if nextSkin then
                            currentPath = skins[nextSkin].texturesPath
                        end
                    end
                end

                if not found then
                    -- pass out the final string anyway so resource loader can gracefully fail
                    LOG("Warning: Unable to find file ", filespec)
                    found = filespec
                end
            end

            if(not UIFileCache[skin]) then
                UIFileCache[skin] = {}
            end

            UIFileCache[skin][filespec] = found
        end

        return UIFileCache[skin][filespec]
    end
end