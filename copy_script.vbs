Dim objFSO, objFile, objFolder, objShell, objConfigFile, objSourceFolder
Dim config, baseFolder, copyFolder, source, baseSource, copySource, line, matches, flgpart, oldpart, newpart, filepath, folderpath, newfilepath, newfolderpath, extension
Dim re, reMatch, reMatches, reConfig, reConfigMatch, reConfigMatches

' �ݒ�t�@�C����ǂݍ���
config = "config.txt"

' �R�s�[���A�R�s�[��f�B���N�g����ݒ�
baseFolder = "MOD_BASE"
copyFolder = "MOD"

' ��ƃf�B���N�g����ݒ�
Set objShell = CreateObject("WScript.Shell")
baseSource = objShell.CurrentDirectory & "\" & baseFolder
copySource = objShell.CurrentDirectory & "\" & copyFolder

' FileSystemObject���쐬
Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objConfigFile = objFSO.OpenTextFile(config, 1)

' ���K�\���I�u�W�F�N�g���쐬
Set re = CreateObject("VBScript.RegExp")
re.Pattern = "^(.*?):(.*?)=(.*)$"
re.IgnoreCase = True

' �ݒ�t�@�C���̊e�s������
Do Until objConfigFile.AtEndOfStream
    line = objConfigFile.ReadLine

    If re.Test(line) Then
        Set reMatches = re.Execute(line)
        Set reMatch = reMatches(0)
        flgpart = Trim(reMatch.SubMatches(0))
        oldpart = Trim(reMatch.SubMatches(1))
        newpart = Trim(reMatch.SubMatches(2))
        If flgpart = "f" Then
            WScript.Echo "���݃`�F�b�N�p�X: " & copySource & "\" & "*" & newpart & "*"
            ' �R�s�[��̃t�H���_�܂��̓t�@�C�������݂��Ă��邩�m�F
            If isExistsFolderAndFile(copySource, "*" & newpart & "*") Then
                Dim result
                result = objShell.Popup("�R�s�[��̃t�H���_�܂��̓t�@�C�������݂��Ă��܂��B" & vbCrLf  & "�㏑�����܂����H", 0, "�m�F", 4 + 32)
                If result = 7 Then ' No��I�������ꍇ
                    WScript.Echo "�����𒆎~���܂��B"
                    WScript.Quit
                Else
                    WScript.Echo "�㏑���ŏ����𑱍s���܂��B"
                End If
            End If

            ' �t�@�C���ƃt�H���_���ċA�I�ɏ���
            Set objSourceFolder = objFSO.GetFolder(baseSource)
            ProcessFolder objSourceFolder, oldpart, newpart, baseFolder, copyFolder
        End If
    Else
        If Left(line, 1) = "#" Then
            'WScript.Echo "�R�����g�s: " & line
        Else
            WScript.Echo "�s���}�b�`���܂���ł���: " & line
        End If
    End If

Loop
objConfigFile.Close

WScript.Echo "�������܂����B"
WScript.Quit

Function isExistsFolderAndFile(folderPath, chkPattern)
    Dim objFSO, objFolder, objSubFolder, objFile, re

    ' FileSystemObject���쐬
    Set objFSO = CreateObject("Scripting.FileSystemObject")

    ' ���K�\���I�u�W�F�N�g���쐬
    Set re = CreateObject("VBScript.RegExp")
    re.Pattern = "^" & Replace(chkPattern, "*", ".*") & "$"
    re.IgnoreCase = True

    ' �t�H���_�����݂��邩�`�F�b�N
    If objFSO.FolderExists(folderPath) Then
        Set objFolder = objFSO.GetFolder(folderPath)
        
        ' �T�u�t�H���_���`�F�b�N
        For Each objSubFolder In objFolder.SubFolders
            If re.Test(objSubFolder.Name) Then
                WScript.Echo "��v����t�H���_��������܂���: " & objSubFolder.Path
                isExistsFolderAndFile = True
                Exit Function
            End If
        Next
        
        ' �t�@�C�����`�F�b�N
        For Each objFile In objFolder.Files
            If re.Test(objFile.Name) Then
                WScript.Echo "��v����t�@�C����������܂���: " & objFile.Path
                isExistsFolderAndFile = True
                Exit Function
            End If
        Next
    End If

    isExistsFolderAndFile = False
End Function

Sub ProcessFolder(folder, oldpart, newpart, baseFolder, copyFolder)
    Dim subFolder, file, filepath, folderpath, newfilepath, newfolderpath, extension, objInputFile, objOutputFile, objSubConfigFile, hasBOM, firstBytes, i

    ' �t�H���_���̊e�t�@�C��������
    For Each file In folder.Files
        filepath = file.Path
        folderpath = file.ParentFolder.Path
        newfilepath = Replace(Replace(filepath, baseFolder, copyFolder), oldpart, newpart)
        newfolderpath = Replace(Replace(folderpath, baseFolder, copyFolder), oldpart, newpart)
        extension = objFSO.GetExtensionName(file)

        If folderpath <> "" Then
            ' �V�����t�@�C���̃f�B���N�g�����쐬
            If Not objFSO.FolderExists(newfolderpath) Then
                CreateFullPath(newfolderpath)
            End If

            ' �g���q�Ɋ�Â��ď����𕪊�
            If LCase(extension) = "dds" Then
                ' �摜�t�@�C�����R�s�[
                objFSO.CopyFile filepath, newfilepath, True
            ElseIf LCase(extension) = "txt" Then
                ' SJIS�̃e�L�X�g�t�@�C��������
                If objFSO.FileExists(newfilepath) Then objFSO.DeleteFile(newfilepath)

                ' ���̓t�@�C����1�s���ǂݍ��݁A�u�����ďo�̓t�@�C���ɏ�������
                Set objInputFile = objFSO.OpenTextFile(filepath, 1)
                Set objOutputFile = objFSO.CreateTextFile(newfilepath, True)
                Do Until objInputFile.AtEndOfStream
                    line = objInputFile.ReadLine
                    Set objSubConfigFile = objFSO.OpenTextFile(config, 1)
                    Do Until objSubConfigFile.AtEndOfStream
                        configLine = objSubConfigFile.ReadLine
                        If re.Test(configLine) Then
                            Set reConfigMatches = re.Execute(configLine)
                            Set reConfigMatch = reConfigMatches(0)
                            flgstr = Trim(reConfigMatch.SubMatches(0))
                            oldstr = Trim(reConfigMatch.SubMatches(1))
                            newstr = Trim(reConfigMatch.SubMatches(2))
                            If flgstr = "n" Then
                                line = Replace(line, oldstr, newstr)
                            End If
                        End If
                    Loop
                    objSubConfigFile.Close
                    objOutputFile.WriteLine line
                Loop
                objInputFile.Close
                objOutputFile.Close
            Else
                ' UTF8�̃e�L�X�g�t�@�C��������
                If objFSO.FileExists(newfilepath) Then objFSO.DeleteFile(newfilepath)

                ' ADODB.Stream�I�u�W�F�N�g���쐬���ăt�@�C�����o�C�i�����[�h�ŊJ��
                Set objStream = CreateObject("ADODB.Stream")
                objStream.Type = 1 ' adTypeBinary
                objStream.Open
                objStream.LoadFromFile(filepath)
                ' �t�@�C���̍ŏ���3�o�C�g��ǂݎ��
                firstBytes = objStream.Read(3)
                objStream.Close

                ' BOM�̗L�����m�F
                hasBOM = (AscB(firstBytes) = Chr(&HEF) & Chr(&HBB) & Chr(&HBF))

                ' ADODB.Stream�I�u�W�F�N�g���쐬���ē��̓t�@�C����UTF-8�ŊJ��
                Set objStream = CreateObject("ADODB.Stream")
                objStream.Type = 2 ' adTypeText
                objStream.Charset = "UTF-8"
                objStream.Open
                objStream.LoadFromFile(filepath)

                ' ADODB.Stream�I�u�W�F�N�g���쐬���ďo�̓t�@�C����UTF-8�ŊJ��
                Set objStreamOut = CreateObject("ADODB.Stream")
                objStreamOut.Type = 2 ' adTypeText
                objStreamOut.Charset = "UTF-8"
                objStreamOut.Open

                ' BOM������ꍇ�ABOM��ǉ�
                If hasBOM Then
                    objStreamOut.WriteText Chr(&HEF) & Chr(&HBB) & Chr(&HBF)
                End If

                ' ���̓t�@�C����1�s���ǂݍ��݁A�u�����ďo�̓t�@�C���ɏ�������
                Do Until objStream.EOS
                    line = objStream.ReadText(-2) ' -2 for reading line by line
                    Set objSubConfigFile = objFSO.OpenTextFile(config, 1)
                    Do Until objSubConfigFile.AtEndOfStream
                        configLine = objSubConfigFile.ReadLine
                        If re.Test(configLine) Then
                            Set reConfigMatches = re.Execute(configLine)
                            Set reConfigMatch = reConfigMatches(0)
                            flgstr = Trim(reConfigMatch.SubMatches(0))
                            oldstr = Trim(reConfigMatch.SubMatches(1))
                            newstr = Trim(reConfigMatch.SubMatches(2))
                            If flgstr = "n" Then
                                line = Replace(line, oldstr, newstr)
                            End If
                        End If
                    Loop
                    objSubConfigFile.Close
                    objStreamOut.WriteText line & vbLf
                Loop
                objStream.Close

                ' �o�̓t�@�C����ۑ�
                objStreamOut.SaveToFile newfilepath, 2 ' adSaveCreateOverWrite
                objStreamOut.Close

            End If
        End If
    Next

    ' �T�u�t�H���_���ċA�I�ɏ���
    For Each subFolder In folder.SubFolders
        ProcessFolder subFolder, oldpart, newpart, baseFolder, copyFolder
    Next
End Sub

Sub CreateFullPath(path)
    Dim objFSO, arrDirs, currentPath, i
    
    ' FileSystemObject���쐬
    Set objFSO = CreateObject("Scripting.FileSystemObject")
    
    ' �p�X���f�B���N�g�����Ƃɕ���
    arrDirs = Split(path, "\")
    currentPath = arrDirs(0)
    
    ' �e�f�B���N�g�����쐬
    For i = 1 To UBound(arrDirs)
        currentPath = currentPath & "\" & arrDirs(i)
        If Not objFSO.FolderExists(currentPath) Then
            objFSO.CreateFolder(currentPath)
        End If
    Next
End Sub
