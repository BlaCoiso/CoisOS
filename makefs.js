/*jshint node:true, esversion:6 */
const fs = require("fs");
const FLAGS = { READONLY: 1, HIDDEN: 2, SYSTEM: 4, VOL_LBL: 8, SUBDIR: 0x10, ARCHIVE: 0x20, DEVICE: 0x40 };
const FileStruct = { name: "", path: "", flags: 0 };
const FSData = require("./filesystem.json");
const clusterSize = FSData.clusterSize * 512;
let nextFreeCluster = 2;
let fileCount = 0;
let FATBuffer = new Buffer(FSData.FATSize * 512);
let RootDirBuffer = new Buffer(FSData.rootEntryCount * 32);
let FileDataBuffer = new Buffer(clusterSize * 4);

function allocFileBuffer() {
    let newSize = FileDataBuffer.byteLength + 4 * clusterSize;
    let newBuf = new Buffer(newSize);
    FileDataBuffer.copy(newBuf);
    FileDataBuffer = newBuf;
}

/**
 * Writes the file to the buffers
 * @param {FileStruct} file 
 */
function writeFile(file) {
    let fdata = fs.readFileSync(file.path);
    let fstats = fs.statSync(file.path);
    let fnamefull = file.name.toUpperCase().split(".");
    let fext = fnamefull[1] || "";
    let fname = fnamefull[0];
    if (fname.length > 8) fname = fname.slice(0, 8);
    else while (fname.length < 8) fname += " ";
    if (fext.length > 3) fext = fext.slice(0, 3);
    else while (fext.length < 3) fext += " ";
    let flags = file.flags || 0;
    let createDate = fstats.birthtime;
    let cSec = Math.floor(createDate.getUTCSeconds() / 2);
    let cMin = createDate.getUTCMinutes();
    let cHour = createDate.getUTCHours();
    let cYear = createDate.getUTCFullYear() - 1980;
    let cMon = createDate.getUTCMonth();
    let cDay = createDate.getUTCDay();

    let modifyDate = fstats.mtime;
    let mSec = Math.floor(modifyDate.getUTCSeconds() / 2);
    let mMin = modifyDate.getUTCMinutes();
    let mHour = modifyDate.getUTCHours();
    let mYear = modifyDate.getUTCFullYear() - 1980;
    let mMon = modifyDate.getUTCMonth();
    let mDay = modifyDate.getUTCDay();

    let flen = fstats.size;
    let dirOffset = fileCount * 32;
    RootDirBuffer.write(fname, dirOffset);
    dirOffset += 8;
    RootDirBuffer.write(fext, dirOffset);
    dirOffset += 3;
    RootDirBuffer.writeUInt8(flags, dirOffset++);
    RootDirBuffer.writeUInt8(0, dirOffset++);//Reserved
    RootDirBuffer.writeUInt8(0, dirOffset++);//First Char of deleted
    RootDirBuffer.writeUInt16LE(cSec | (cMin << 5) | (cHour << 11), dirOffset);
    dirOffset += 2;
    RootDirBuffer.writeUInt16LE(cDay | (cMon << 5) | (cYear << 9), dirOffset);
    dirOffset += 2;
    RootDirBuffer.writeUInt16LE(0, dirOffset);//Last Accessed
    dirOffset += 2;
    RootDirBuffer.writeUInt16LE(0, dirOffset);//Reserved
    dirOffset += 2;
    RootDirBuffer.writeUInt16LE(mSec | (mMin << 5) | (mHour << 11), dirOffset);
    dirOffset += 2;
    RootDirBuffer.writeUInt16LE(mDay | (mMon << 5) | (mYear << 9), dirOffset);
    dirOffset += 2;
    RootDirBuffer.writeUInt16LE(nextFreeCluster, dirOffset);
    dirOffset += 2;
    RootDirBuffer.writeUInt32LE(flen, dirOffset);
    fileCount++;

    let processedBytes = 0;
    while (processedBytes < flen) {
        fdata.copy(FileDataBuffer, (nextFreeCluster - 2) * clusterSize, processedBytes, Math.min(processedBytes + clusterSize, flen));
        processedBytes += clusterSize;
        if (processedBytes >= flen) FATBuffer.writeUInt16LE(0xFFFF, nextFreeCluster * 2);
        else FATBuffer.writeUInt16LE(nextFreeCluster + 1, nextFreeCluster * 2);
        ++nextFreeCluster;
        if (FileDataBuffer.byteLength < nextFreeCluster * clusterSize) allocFileBuffer();
    }
}

FATBuffer.writeUInt16LE(0xFFF8, 0);
FATBuffer.writeUInt16LE(0xFFFF, 2);
for (let file of FSData.files) {
    writeFile(file);
}
fs.writeFileSync("fat.bin", FATBuffer);
fs.writeFileSync("rootdir.bin", RootDirBuffer);
fs.writeFileSync("fs_data.bin", FileDataBuffer);
console.log(`Written ${fileCount} files to ${nextFreeCluster - 2} clusters.`);
