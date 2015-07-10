$IF ASM41
declare w$3780 address public data(0),
	b$3782 byte public data(80h),
	b$3783 byte public data(81h);
$ENDIF
declare	spaces24(*) byte public data('                        ', 0),
	ascCRLF(*) byte public data(0Dh, 0Ah, 0),
	signonMsg(*) byte data(0Dh, 0Ah),
	aIsisIi80808085(*) byte public data('ISIS-II 8080/8085 MACRO ASSEMBLER, V4.1', 9, 9),
	aModulePage(*) byte public data('MODULE ', 9, ' PAGE ', 0),
	bZERO byte public data(0),
	bTRUE byte public data(0FFh),
	copyright(*) byte data('(C) 1976,1977,1979,1980 INTEL CORP'),
	aStack(*) byte public data(0Dh, 0Ah, 'STACK', 0),
	aTable(*) byte public data(0Dh, 0Ah, 'TABLE', 0),
	aCommand(*) byte public data(0Dh, 0Ah, 'COMMAND', 0),
	aEof(*) byte public data(0Dh, 0Ah, 'EOF', 0),
	aFile(*) byte public data(0Dh, 0Ah, 'FILE', 0),
	aMemory(*) byte public data(0Dh, 0Ah, 'MEMORY', 0),
	aError(*) byte public data(' ERROR', 0Dh, 0Ah, 0),
	aError$0(*) byte public data(' ERROR, ', 0Dh,0Ah, 0),
	errStrs(*) address public data(.aStack, .aTable, .aCommand, .aEof, .aFile, .aMemory),
	errStrsLen(*) byte public data(7, 7, 9, 5, 6, 8),
	aBadSyntax(*) byte public data('BAD SYNTAX', 0Dh, 0Ah),
	aCo(*) byte public data(':CO:', 0);

start$ov4$5:
	call getAsmFile;
	phase = 1;
	call resetData;
	call initialControls;
$IF ASM41
	macrofd = inOpen(.aF0Asmac$tmp, 3);
$ENDIF
	if ctlOBJECT then
	do;
		call delete(.objFile, .statusIO);
		objfd = inOpen(.objFile, 3);
	end;

	if ctlXREF then
	do;
		xreffd = inOpen(.aF0Asxref$tmp, 2);
		outfd = xreffd;
	end;

	call sub$540D;
	phase = 2;
	if ctlOBJECT then
	do;
		if r$extnames1.len > 0 then
			call writeRec(.r$extnames1);

		if w6750 = 0 then
			call writeModhdr;

		call sub$70EE;
	end;

	if ctlPRINT then
		outfd = inOpen(.lstFile, 2);

	call resetData;
	call initialControls;
	call sub$540D;
	if ctlPRINT then
	do;
		call asmComplete;
		call flushout;
	end;

	if ctlOBJECT then
	do;
		call ovl11;
		call writeModend;
	end;

	if not strUCequ(.aCo, .lstFile) then
		call ovl9;

	call ovl10;
