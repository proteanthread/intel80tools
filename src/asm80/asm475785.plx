asm80$47$57$85: do;
$IF OVL4
$include(asm47.ipx)
$ELSEIF OVL5
$include(asm57.ipx)
$ELSE
$include(asm85.ipx)
$ENDIF

$IF BASE
declare	CHKOVL$2 lit	'call OvlMgr(2)';
$ELSE
declare	CHKOVL$2 lit	' ';
$ENDIF

			/* 0    1    2    3    4    5    6    7    8    9    A    B    C    D    E    F */
declare isExprOrMacroMap(*) bool data(
			   0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,
			   0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0,   0,   0,   0,   0,   0,
			   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
			   0,   0,   0,   0,   0,   0,   0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh, 0,  0FFh,
			   0FFh,0FFh),
   isInstrMap(*) bool data(0,   0FFh,0FFh,0FFh,0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
		           0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0FFh,0FFh,0,   0,   0,   0,
			   0,   0,   0,   0,   0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0,
			   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
			   0FFh,0FFh);

declare pad byte;

declare	accum(4) byte at(.accum1);


ChkSegAlignment: procedure(seg) public;	/* seg = 0 => CSEG, seg = 1 => DSEG */
	declare seg byte;

	if segHasData(seg) then
	do;
		if HaveTokens then
		do;
			accum1 = GetNumVal;
			if alignTypes(seg) <> accum1$lb then
				call ExpressionError;
		end;
		else if alignTypes(seg) <> 3 then	/* no speficier - check byte algined */
			call ExpressionError;
	end;
	else
	do;
		segHasData(seg) = TRUE;
		if HaveTokens then
		do;
			accum1 = GetNumVal;
			if accum1 = 1 or accum1 = 2 then	/* only allow inPage and Page */
				alignTypes(seg) = low(accum1);
			else
				call ExpressionError;
		end;
	end;
end;


Cond2Acc: procedure(cond) public;	/* convert conditional result to accum1 */
	declare cond byte;		/* 0 or 0ffffh */

	accum1 = cond;
	if accum1 then
		accum1 = 0FFFFh;
end;

UpdateHiLo: procedure(hilo) public;
	declare hilo byte;

	if (acc1Flags and (UF$EXTRN + UF$SEGMASK)) <> 0 then
		acc1Flags = acc1Flags and 0E7h or hilo;
end;

HandleOp: procedure public;
	do case leftOp;
/* 0 */		;
/* 1 */		call FinishLine;		/* CR */
/* 2 */		goto case3;			/* ( */
/* 3 */ case3:	do;				/* ) */
			if not (leftOp = T$LPAREN and rightOp = T$RPAREN) then
				call BalanceError;

			if tokenType(0) = O$DATA then
			do;
				tokenSize(0) = 1;
				tokenAttr(0) = 0;
				b6B36 = TRUE;
			end;

			inParen = inNestedParen;
			if rightOp = T$RPAREN then
				b6B2C = TRUE;
		end;
/* 4 */		accum1 = accum1 * accum2;	/* * */
/* 5 */		accum1 = accum1 + accum2;	/* + */
/* 6 */		do;				/* , */
			call SyntaxError;
			call PopToken;
		end;
/* 7 */		accum1 = accum1 - accum2;	/* - */
/* 8 */		;				/* unary + */
/* 9 */		do;				/* / */
			if accum2 = 0 then
				call ValueError;

			accum1 = accum1 / accum2;
		end;
/* 10 */	accum1 = -accum1;			/* unary - */
/* 11 */	call Cond2Acc(accum1 = accum2);		/* EQ */
/* 12 */	call Cond2Acc(accum1 < accum2);		/* LT */
/* 13 */	call Cond2Acc(accum1 <= accum2);	/* LE */
/* 14 */	call Cond2Acc(accum1 > accum2);		/* GT */
/* 15 */	call Cond2Acc(accum1 >= accum2);	/* GE */
/* 16 */	call Cond2Acc(accum1 <> accum2);	/* NE */
/* 17 */	accum1 = not accum1;			/* NOT */
/* 18 */	accum1 = accum1 and accum2;		/* AND */
/* 19 */	accum1 = accum1 or accum2;		/* OR */
/* 20 */	accum1 = accum1 xor accum2;		/* XOR */
/* 21 */	do;					/* MOD */
			if accum2 = 0 then
				call ValueError;
			accum1 = accum1 mod accum2;
		end;
/* 22 */	do;					/* SHL */
			if accum2$lb <> 0 then
				accum1 = shl(accum1, accum2);
		end;
/* 23 */	do;					/* SHR */
			if accum2$lb <> 0 then
				accum1 = shr(accum1, accum2);
		end;
/* 24 */	do;					/* HIGH */
			accum1 = high(accum1);
			call UpdateHiLo(UF$HIGH);
		end;
/* 25 */	do;					/* LOW */
			accum1 = low(accum1);
			call UpdateHiLo(UF$LOW);
		end;
/* 26 */	do;					/* DB ? */
			if tokenType(0) <> O$STRING then
			do;
				accum1 = GetNumVal;
				if accum1$hb - 1 < 0FEh then	/* not 0 or FF */
					call ValueError;
				b6B28 = 22h;
				if (acc1Flags and UF$BOTH) = UF$BOTH then
				do;
					call ValueError;
					acc1Flags = acc1Flags and 0E7h or UF$LOW;
				end;
			end;
			else
			do;
				acc1Flags = 0;
				tokenType(0) = O$DATA;
			end;

			if IsReg(acc1ValType) then
				call OperandError;
			b6B2D = O$DATA;
			inDB = TRUE;
		end;
/* 27 */	do;					/* DW ? */
			b6B2D = O$DATA;
			inDW = TRUE;
		end;
/* 28 */	do;					/* DS ? */
			segSize(activeSeg) = segSize(activeSeg) + accum1;
			showAddr = TRUE;
		end;
/* 29 */ case29:					/* EQU ? */
		do;
			showAddr = TRUE;
			if (acc1Flags and UF$EXTRN) = UF$EXTRN then
			do;
				call ExpressionError;
				acc1Flags = 0;
			end;
			labelUse = 1;
			call Sub5819$5CE8(accum1, (K$SET + 4) - leftOp);	/* 4 for set, 5 for equ */
			expectingOperands = FALSE;
		end;
/* 30 */	goto case29;				/* SET ? */
/* 31 */	do;					/* ORG ? */
			showAddr = TRUE;
			if (acc1Flags and UF$EXTRN) <> UF$EXTRN then
			do;
				if (acc1Flags and UF$BOTH) <> 0 then
					if (acc1Flags and UF$SEGMASK) <> activeSeg
					    or (acc1Flags and UF$BOTH) <> UF$BOTH then
						call ExpressionError;
			end;
			else
				call ExpressionError;

			if ctlOBJECT then
				if segSize(activeSeg) > maxSegSize(activeSeg) then
					maxSegSize(activeSeg) = segSize(activeSeg);
			segSize(activeSeg) = accum1;
		end;
/* 32 */	do;					/* END ? */
			if tokenIdx > 0 then
			do;
				startOffset = GetNumVal;
				startDefined = 1;
				startSeg = acc1Flags and 7;
				if (acc1Flags and UF$EXTRN) = UF$EXTRN then
					call ExpressionError;
				if IsReg(acc1ValType) then
					call OperandError;

				showAddr = TRUE;
			end;
$IF OVL4
			kk = b905E;
			b905E = 0;

			if macroCondSP > 0 or kk then
$ELSE
			if ifDepth > 0 then
$ENDIF
				call NestingError;
			if rightOp <> T$CR then
				call SyntaxError;
			if inParen then
				b6B33 = TRUE;
			else
				call SyntaxError;

		end;
/* 33 */	do;					/* IF ? */
			if inParen then
			do;
				b6B32 = TRUE;
				call NestIF(2);
				b6881 = TRUE;
				if skipping(0) = FALSE then
					skipping(0) = not ((low(accum1) and 1) = 1);
				inElse(0) = FALSE;
			end;
		end;
/* 34 */	do;					/* ELSE ? */
			b6B32 = TRUE;
$IF OVL4
			if macroCondStk(0) <> 2 then
$ELSE
			if ifDepth = 0 then
$ENDIF
				call NestingError;
			else if not inElse(0) then
			do;
				if not skipping(0) then
					skipping(0) = TRUE;
				else
					skipping(0) = skipping(ifDepth);
				inElse(0) = TRUE;
			end;
			else
				call NestingError;
		end;
/* 35 */	do;					/* ENDIF ? */
			if inParen then
			do;
				b6B32 = TRUE;
				call UnnestIF(2);
			end;
		end;
/* 36 */	do;					/* LXI ? */
			if nameLen = 1 then
				if name(0) = 'M' then
					call SyntaxError;
			call MkCode(85h);
		end;
/* 37 */	do;				/* POP DAD PUSH INX DCX ? */
			if nameLen = 1 then
				if name(0) = 'M' then
					call SyntaxError;
			call MkCode(5);
		end;
/* 38 */	call MkCode(7);		/* LDAX STAX ? */
/* 39 */	call MkCode(2);		/* ADC ADD SUB ORA SBB XRA ANA CMP ? */
/* 40 */	call MkCode(8);		/* ADI OUT SBI ORI IN CPI SUI XRI ANI ACI ? */
/* 41 */	call MkCode(46h);		/* MVI ? */
/* 42 */	call MkCode(6);		/* INR DCR ? */
/* 43 */	call MkCode(36h);		/* MOV */
/* 44 */	call MkCode(0);		/* CZ CNZ JZ STA JNZ JNC LHLD */
						/* CP JC SHLD CPE CPO CM LDA JP JM JPE */
						/* CALL JPO CC CNC JMP */
/* 45 */	call MkCode(0);		/* RNZ STC DAA DI SIM SPHL RLC */
						/* RP RAL HLT RM RAR RPE RET RIM */
						/* PCHL CMA CNC RPO EI XTHL NOP */
						/* RC RNX XCHG RZ RRC */
/* 46 */	call MkCode(6);		/* RST */
/* 47 */	activeSeg = 0;			/* ASEG ? */
/* 48 */	do;				/* CSEG ? */
			activeSeg = 1;
			call ChkSegAlignment(0);
		end;
/* 49 */	do;				/* DSEG ? */
			activeSeg = 2;
			call ChkSegAlignment(1);
		end;

/* 50 */	do;				/* PUBLIC */
			inPublic = TRUE;
			labelUse = 0;
			call Sub5819$5CE8(0, 6);
		end;
/* 51 */	do;				/* EXTRN ? */
			inExtrn = TRUE;
			if externId = 0 and IsPhase1 and ctlOBJECT then
			do;
				CHKOVL$2;
				call WriteModhdr;
			end;
			labelUse = 0;
			call Sub5819$5CE8(externId, 2);
			if IsPhase1 and ctlOBJECT and not badExtrn then
			do;
				CHKOVL$2;
				call WriteExtName;
			end;
			if not badExtrn then
				externId = externId + 1;
			badExtrn = 0;
		end;
/* 52 */	do;				/* NAME */
			if tokenIdx <> 0 and noOpsYet then
			do;
				/* set the module name in the header - padded to 6 chars */
				call move(6, .spaces6, .aModulePage);
				call move(moduleNameLen := nameLen, .name, .aModulePage);
			end;
			else
				call SourceError('R');

			call PopToken;
		end;
/* 53 */	segSize(SEG$STACK) = accum1;	/* STKLN ? */
$IF OVL4
/* 54 */	call Sub7517;			/* MACRO ? */
/* 55 */	call Sub753E;
/* 56 */	call Sub75FF;			/* ENDM */
/* 57 */	call Sub76CE;			/* EXITM */
/* 58 */	do;
			tmac$mtype = 4;
			call Sub7327;
		end;
/* 59 */	call Sub72A4(1);		/* IRP ? */
/* 60 */	call Sub72A4(2);		/* IRPC */
/* 61 */	call Sub770B;
/* 62 */	call Sub7844;			/* REPT ? */
/* 63 */	call Sub787A;			/* LOCAL */
/* 64 */	call Sub78CE;
/* 65 */	do;				/* NUL */
			call Cond2Acc(tokenType(0) = K$NUL);
			call PopToken;
			acc1Flags = 0;
		end;
$ENDIF
	end;

	if leftOp <> T$CR then
		noOpsYet = FALSE;
end;

ParseLine: procedure public;

	IsExpressionOp: procedure byte;
		if effectiveToken > 3 then
			if effectiveToken <> T$COMMA then
				if effectiveToken < 1Ah then
					return TRUE;
		return FALSE;
	end;

	isVar: procedure(arg1b) byte;
		declare arg1b byte;
		return arg1b = O$ID or arg1b = O$64;
	end;


	Sub53F8: procedure;
		if not isInstrMap(leftOp) then
			b6B34 = FALSE;
	end;



	do while 1;
		if not (effectiveToken = T$CR or effectiveToken >= K$END and effectiveToken <= K$ENDIF) and skipping(0)
$IF OVL4
	           or (b4181(effectiveToken) < 128 or b9058) and b905E

$ENDIF
	        then
		do;
			needsAbsValue = FALSE;
			call PopToken;
			return;
		end;
		
		if phase <> 1 then
			if inExpression then
				if IsExpressionOp then
					if GetPrec(effectiveToken) <= GetPrec(opStack(opSP)) then
						call ExpressionError;

		if GetPrec(rightOp := effectiveToken) > GetPrec(leftOp := opStack(opSP)) or rightOp = T$LPAREN then
		do;
			if opSP >= 16 then
			do;
				opSP = 0;
				call StackError;
			end;
			else
				opStack(opSP := opSP + 1) = rightOp;
			if rightOp = T$LPAREN then
			do;
				inNestedParen = inParen;
				inParen = TRUE;
			end;
			if phase > 1 then
				inExpression = IsExpressionOp;
			return;
		end;

		inExpression = 0;
		if not inParen and leftOp > 3 then
			call SyntaxError;

		if leftOp = O$NONE then
			leftOp = rightOp;
		else
			opSP = opSP - 1;
		

		if (b6B28 := b4181(leftOp)) then
		do;
			accum2 = GetNumVal;
			acc2Flags = acc1Flags;
			acc2NumVal = acc1NumVal;
			acc2ValType = acc1ValType;
		end;

		if (b6B28 := ror(b6B28, 1)) then
			accum1 = GetNumVal;

		if not hasVarRef then
			hasVarRef = isVar(acc1ValType) or isVar(acc2ValType);

		b6B2D = O$NUMBER;
		if leftOp > T$RPAREN and leftOp < K$DB then	/* expression leftOp */
			call Sub4291;
		else
		do;
			call Sub53F8;
			call Sub4274;
		end;

		call HandleOp;
		if not isExprOrMacroMap(leftOp) then
			inParen = FALSE;

		if b6B2C then
		do;
			b6B2C = FALSE;
			return;
		end;

		if leftOp <> K$DS and showAddr then		/* DS */
			effectiveAddr = accum1;

		if (b6B28 and 1Eh) <> 0 then
			call PushToken(b6B2D);

		do ii = 0 to 3;
			if (b6B28 := ror(b6B28, 1)) then
				call CollectByte(accum(ii));
		end;

		tokenAttr(0) = acc1Flags;
		tokenSymId(0) = acc1NumVal;
		if ror(b6B28, 1) then
			if rightOp = T$COMMA then
			do;
				effectiveToken = leftOp;
				inParen = TRUE;
			end;
	end;
end;



DoPass: procedure public;
	do while finished = FALSE;
		call TokeniseLine;
		call ParseLine;
	end;
end;

end;