asm4c$ov2: do;
$IF OVL4
$include(asm4c.ipx)
$ELSE
$include(asmov2.ipx)
$ENDIF

declare	fixupInitialLen(*) byte data(1, 2, 1, 3),
	fixupRecLenPtrs(*) address data(.r$publics.len, .r$interseg.len, .r$extref.len, .r$content.len),
	fixupRecLenChks(*) byte data(123, 58, 57, 124),
	b6D7E(*) byte data(10, 12h, 40h); /* 11 bits 00010010010 index left to right */


declare	r$modhdr MODHDR$T initial(2), (dta$p, recSym$p) address;



writeRec: procedure(rec$p) public;
	declare rec$p address,
		len$p address, recLen address,
		i byte, crc byte;
	declare len based len$p address;
	declare ch based len$p byte;

	len$p = rec$p + 1;
	recLen = (len := len + 1) + 3;	/* include crc byte + type + len word */
	crc = 0;			/* crc */
	len$p = len$p - 1;
	do i = 2 to recLen;
		crc = crc - ch;
		len$p = len$p + 1;
	end;
	ch = crc;			/* insert crc byte */
	call write(objfd, rec$p, recLen, .statusIO);
	call ioErrChk;
end;


getFixupType: procedure byte;
	declare attr byte;
	if ((attr := tokenAttr(spIdx)) and 5Fh) = 0 then
		return 3;
	if (attr and 40h) <> 0 then	/* external */
		return 2;
	if (fixupSeg := attr and 7) = 0 then	/* absolute */
		return 3;
	return (fixupSeg <> activeSeg) and 1;
end;


reinitFixupRecs: procedure public;
	declare i byte;
	declare wrd based dta$p address;
	do i = 0 to 3;
		ii = (i - 1) and 3;
		dta$p = fixupRecLenPtrs(ii);
		if wrd > fixupInitialLen(ii) then
			call writeRec(dta$p - 1);

		wrd = fixupInitialLen(ii);
		fixIdxs(ii) = 0;
		if curFixupType <>  ii then
			initFixupReq(ii) = TRUE;
	end;
	r$content.offset = itemOffset + segSize(r$content.segid := activeSeg);
	r$publics.segid = curFixupHiLoSegId;
	r$interseg.segid = tokenAttr(spIdx) and 7;
	r$interseg.hilo, r$extref.hilo = curFixupHiLoSegId;
end;



sub$6EE1: procedure;
	declare effectiveOffset address;

	declare wrd based dta$p address;

	dta$p = fixupRecLenPtrs(curFixupType := getFixupType);
	if wrd > fixupRecLenChks(curFixupType) or r$content.len + tokenSize(spIdx) > 124 then
		call reinitFixupRecs;

	if firstContent then
	do;
		firstContent = FALSE;
		r$content.offset = segSize(r$content.segid := activeSeg) + itemOffset;
	end;
	else if r$content.segid <> activeSeg
	      or (effectiveOffset := r$content.offset + fix6Idx) <> segSize(activeSeg) + itemOffset
	      or effectiveOffset < r$content.offset then
		call reinitFixupRecs;


	do case curFixupType;
/* 0 */		do;
			if initFixupReq(0) then
			do;
				initFixupReq(0) = FALSE;
				r$publics.segid = curFixupHiLoSegId;
			end;
			else if r$publics.segid <> curFixupHiLoSegId then
				call reinitFixupRecs;
		end;
/* 1 */		do;
			if initFixupReq(1) then
			do;
				initFixupReq(1) = FALSE;
				r$interseg.segid = tokenAttr(spIdx) and 7;
				r$interseg.hilo = curFixupHiLoSegId;
			end;
			else if r$interseg.hilo <> curFixupHiLoSegId or (tokenAttr(spIdx) and 7) <> r$interseg.segid then
				call reinitFixupRecs;
		end;
/* 2 */		do;
			if initFixupReq(2) then
			do;
				initFixupReq(2) = FALSE;
				r$extref.hilo = curFixupHiLoSegId;
			end;
			else if r$extref.hilo <> curFixupHiLoSegId then
				call reinitFixupRecs;

		end;
/* 3 */		;		/* abs no fixup */
	end;
end;


recAddContentBytes: procedure;
	declare i byte;

	declare ch based contentBytePtr byte;

	do i = 1 to tokenSize(spIdx);
		r$content.dta(fix6Idx) = ch;
		fix6Idx = fix6Idx + 1;
		contentBytePtr = contentBytePtr + 1;
	end;
	r$content.len = r$content.len + tokenSize(spIdx);
end;



intraSegFix: procedure;
	r$reloc.len = r$reloc.len + 2;
	r$reloc.dta(fix22Idx) = fixOffset;
	fix22Idx = fix22Idx + 1;
end;


interSegFix: procedure;
	r$interseg.len = r$interseg.len + 2;
	r$interseg.dta(fix24Idx) = fixOffset;
	fix24Idx = fix24Idx + 1;
end;

externalFix: procedure;
	r$extref.dta(fix20Idx) = tokenSymId(spIdx);
	r$extref.dta(fix20Idx + 1) = fixOffset;
	r$extref.len = r$extref.len + 4;
	fix20Idx = fix20Idx + 2;
end;

sub$7131: procedure;
	curFixupHiLoSegId = shr(tokenAttr(spIdx) and 18h, 3);
	fixOffset = segSize(activeSeg) + itemOffset;
	if not (inDB or inDW) and (tokenSize(spIdx) = 2 or tokenSize(spIdx) = 3) then
		fixOffset = fixOffset + 1;
	call sub$6EE1;
	contentBytePtr = startItem;
	call recAddContentBytes;
	do case getFixupType;
/* 0 */ 	call intraSegFix;
/* 1 */		call interSegFix;
/* 2 */		call externalFix;
/* 3 */		;			/* no fixup as absolute */
	end;
end;


writeExtName: procedure public;
	declare i byte;

	if r$extnames1.len + 9 > 125 then	/* check room for name */
	do;
		call writeRec(.r$extnames1);	/* flush existing extNam Record */
		r$extnames1.type = OMF$EXTNAMES;
		r$extnames1.len = 0;
		extNamIdx = 0;
	end;
	r$extnames1.len = r$extnames1.len + nameLen + 2;	/* update length for this ref */
	r$extnames1.dta(extNamIdx) = nameLen;		/* write len */
	extNamIdx = extNamIdx + 1;
	do i = 0 to nameLen;			/* and name */
		r$extnames1.dta(extNamIdx + i) = name(i);
	end;

	r$extnames1.dta(extNamIdx + nameLen) = 0;	/* and terminating 0 */
	extNamIdx = extNamIdx + nameLen + 1;	/* update where next ref writes */
end;

writeSymbols: procedure(isPublic);			/* isPublic= TRUE -> PUBLICs else LOCALs */
    declare isPublic byte;
    declare segId byte;
    declare symb based curTokenSym$p (1) byte;

    addSymbol: procedure;
        declare offsetInSeg$p address;
        declare symNam based dta$p (1) byte;
        declare len based recSym$p byte;
        declare symOffset based recSym$p address;
        declare offsetInSeg based offsetInSeg$p address;

        if (symb(1) and 40h) <> 0 then
            return;
        offsetInSeg$p = curTokenSym$p - 2;
        symOffset = offsetInSeg; 
        call unpackToken(curTokenSym$p - 6, (dta$p := (recSym$p := recSym$p + 2) + 1));
        symNam(6) = ' ';	/* trailing space to ensure end */
        len = 0;

        do while symNam(0) <> ' ';	/* find length of name */
            len = len + 1;
            dta$p = dta$p + 1;
        end;
        symNam(0) = 0;			/* terminate name with 0 */
        recSym$p = dta$p + 1;
    end;

    flushSymRec: procedure;
        if (r$publics.len := recSym$p - .r$publics.segid) > 1 then	/* something to write */
            call writeRec(.r$publics);
        r$publics.type = (isPublic and 4) or OMF$LOCALS;		/* PUBLIC or LOCAL */
        r$publics.segid = segId;
        recSym$p = .r$publics.dta;
    end;

    recSym$p = .r$publics.dta;
    do segId = 0 to 4;
        call flushSymRec;
        curTokenSym$p = symTab(1) - 2;		/* point to type byte of user symbol (-1) */

        do while (curTokenSym$p := curTokenSym$p + 8) < endSymTab(1);
        	if recSym$p > .r$publics.dta(114) then		/* make sure there is room */
        		call flushSymRec;

            if (symb(1) and 7) = segId
$IF OVL4
               and symb(0) <> O$3A and sub$3FA9
$ENDIF
               and not testBit(symb(0), .b6D7E) and
               (not isPublic or (symb(1) and 20h) <> 0) then
       	        call addSymbol;
        end;
        call flushSymRec;
    end;
end;



writeModhdr: procedure public;
	declare w based dta$p address;
	declare b based dta$p byte;
	declare i byte;

	/* fill the module name */
	call move((r$modhdr.dta(0) := moduleNameLen), .aModulePage, .r$modhdr.dta(1));
	dta$p = .r$modhdr + moduleNameLen + 4;
	w = 0;	/* the two xx bytes */
	dta$p = dta$p + 1;	/* past first x byte */

	if segSize(SEG$CODE) < maxSegSize(SEG$CODE) then	/* code segment */
		segSize(SEG$CODE) = maxSegSize(SEG$CODE);
	if segSize(SEG$DATA) < maxSegSize(SEG$DATA) then	/* data segment */
		segSize(SEG$DATA) = maxSegSize(SEG$DATA);

	do i = 1 to 4;
		dta$p = dta$p + 1;
		b = i;		/* seg id */
		dta$p = dta$p + 1;
		w = segSize(i);	/* seg size */
		dta$p = dta$p + 2;
		b = alignTypes(i - 1);	/* aln typ */
	end;
	r$modhdr.len = moduleNameLen + 19;	/* set record length */
	call writeRec(.r$modhdr);
end;

writeModend: procedure public;
	declare lenb byte at (.r$eof.len);
	r$modend.modtyp = startDefined;
	r$modend.segid = startSeg;
	r$modend.offset = startOffset;
	call writeRec(.r$modend);
	lenb = 0;
	call writeRec(.r$eof);
end;

ovl8: procedure public;
	itemOffset = 0;
	tokI = 1;
	spIdx = 1;
	if b6B33 then
		;
	else
	do while spIdx <> 0;
		spIdx = nxtTokI;
		endItem = tokStart(spIdx) + tokenSize(spIdx);
		startItem = tokStart(spIdx);
		if isSkipping or not b6B34 then
			endItem = startItem;
		if endItem > startItem then
		do;
			call sub$7131;
			itemOffset = itemOffset + tokenSize(spIdx);
		end;
		if not(inDB or inDW) then
			spIdx = 0;
	end;
end;


ovl11: procedure public;
	if externId <> 0 then
	do;
		call seek(objfd, SEEKABS, .azero, .azero, .statusIO);	/* rewind */
		call writeModhdr;
		call seek(objfd, SEEKEND, .azero, .azero, .statusIO);	/* back to end */
	end;
	r$publics.type = OMF$PUBLICS;		  /* public declarations record */
	r$publics.len = 1;
	r$publics.segid = SEG$ABS;
	r$publics.dta(0) = 0;
	call writeSymbols(TRUE);	  /* EMIT PUBLICS */
	if ctlDEBUG then
		call writeSymbols(FALSE); /* EMIT LOCALS */
end;
end;
