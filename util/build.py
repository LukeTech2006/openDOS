import os, zlib

def main():
    print("Cleaning up dist path...")
    for root, dirs, files in os.walk("dist", topdown=False):
        for name in files:
            print(f"X {os.path.join(root, name)}")
            os.remove(os.path.join(root, name))
        for name in dirs:
            print(f"X {os.path.join(root, name)}")
            os.rmdir(os.path.join(root, name))

    print("\nCopying files...")
    srcPath = "src/"
    distPath = "dist/"
    distPaths = [
        "",
        "fs/dos",
        "fs/license/opendos",
        "fs/license/thirdparty"
    ]
    srcFiles = [
        "bios.lua",
        "fs/init.lua",
        "fs/license/thirdparty/license",
        "fs/license/thirdparty/license.bsd",
        "fs/license/thirdparty/license.mit",
        "fs/license/opendos/license.mit"
    ]

    for path in distPaths:
        try: os.makedirs(distPath + path)
        except: continue
    for fileName in srcFiles:
        print(f"{srcPath + fileName} -> {distPath + fileName}")
        with open(srcPath + fileName, 'rb') as file: newFile = file.read()
        distFile = open(distPath + fileName, 'wb')
        distFile.write(newFile)
        distFile.close()

    srcPath = "src/fs/dos/"
    distPath = "dist/fs/dos/"
    srcFiles = os.listdir(srcPath)
    print("\nCompressing files...")
    for fileName in srcFiles:
        print(f"{srcPath + fileName} -> {distPath + fileName.replace("lua", "clf")}")
        if not fileName.endswith(".lua"): continue
        with open(srcPath + fileName, 'rb') as file: newFile = file.read()
        distFile = open(distPath + fileName.replace("lua", "clf"), 'wb')
        distFile.write(zlib.compress(newFile))
        distFile.close()
    
if __name__ == '__main__':
    main()