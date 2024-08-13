import os, zlib

def main():
    srcPath = "../src/fs/opennt/"
    distPath = "../dist/"
    srcFiles = os.listdir(srcPath)
    print("Compressing files...")
    for fileName in srcFiles:
        if fileName.endswith(".lua"):
            with open(srcPath + fileName, 'r', encoding="UTF-8") as file: newFile = "\n".join(file.readlines())
            if not os.path.exists(distPath): os.mkdir(distPath)
            distFile = open(distPath + fileName.replace("lua", "clf"), 'wb')
            distFile.write(zlib.compress(bytes(newFile, encoding="UTF-8")))
            distFile.close()
    
if __name__ == '__main__':
    main()