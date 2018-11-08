//Kernel calls C Header

//String calls
int StringLength(char *string);
char *PrintString(char *string);
void PrintChar(char chr);
void PrintByteHex(char value);
void PrintHex(int value);
void PrintNewLine();
int UInt2Str(unsigned int value, char *buffer);
void PrintUInt(unsigned int value);
int Int2Str(signed int value, char *buffer);
void PrintInt(signed int value);
void PrintTitle(char *string);
void MemoryCopy(void *dest, void *source, int length);
void StringCopy(char *dest, char *source);
void SubStringCopy(char *dest, char *source, char *length);
void StringConcat(char *dest, char *source);
void DrawBox(int x, int y, int width, int height, int box);
void PrintStringL(char *string, int length);

int GetKey();
int ReadStringSafe(char *buffer, int maxLength);
int ReadString(char *buffer);

//Screen calls
int GetCursorPos();
void SetCursorPos(int pos);
void SetCursorPosXY(int x, int y);
void SetCursorAttribute(int attr);
int GetCursorAttribute();
void SetTextColor(int color);
void SetBackgroundColor(int color);
void DisableCursorUpdate();
void EnableCursorUpdate();
void SetScreenPage(int page);
void ClearScreen();
void SetCursorOffset(int offset);
void ScrollScreen(int lines);

//Filesystem calls
int FindFile(char *filename);
int FindFile8_3(char *filename8_3);
bool ReadFile(char *filename, void *buffer, int segment);
bool ReadFile8_3(char *filename8_3, void *buffer, int segment);
void ReadFileEntry(int *rootDirEntry, void *buffer, int segment);
int GetFileCount();
int ListFiles(char *buffer, int start, int count);

//Disk calls
void ReadSector(int sector, int count, void *buffer, int segment);
void WriteSector(int sector, int count, void *buffer, int segment);

//Debug calls
void DumpMemory(int addr, int segment, int count);
void GetStackTrace(int *FrameBase);