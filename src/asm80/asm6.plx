$IF MACRO
asm6m: do;
$include(:f3:asm6m.ipx)
$ELSE
asm6n: do;
$include(:f3:asm6n.ipx)
$ENDIF

SyntaxError: procedure public;
    call SourceError('Q');
end;

DoubleDefError: procedure public;
    call SourceError('D');
end;

ExpressionError: procedure public;
    call SourceError('E');
end;

CommandError: procedure public;
    call SourceError('C');
end;

OpcodeOperandError: procedure public;
    call SourceError('O');
end;

NameError: procedure public;
    call SourceError('R');
end;

MultipleDefError: procedure public;
    call SourceError('M');
end;

ValueError: procedure public;
    call SourceError('V');
end;

NestingError: procedure public;
    call SourceError('N');
end;

PhaseError: procedure public;
    call SourceError('P');
end;

StackError: procedure public;
    call RuntimeError(0);
end;

FileError: procedure public;
    call RuntimeError(4);
end;

IllegalCharError: procedure public;
    call SourceError('I');
end;

BalanceError: procedure public;
    call SourceError('B');
end;

UndefinedSymbolError: procedure public;
    call SourceError('U');
end;

LocationError: procedure public;
    call SourceError('L');
end;

OperandError: procedure public;
    call SourceError('X');
end;

HaveTokens: procedure byte public;
    return tokenIdx <> 0;
end;


PopToken: procedure public;
    tokStart(0) = tokStart(tokenIdx);
    tokenSym(0) = tokenSym(tokenIdx);
    tokenType(0) = tokenType(tokenIdx);
    tokenAttr(0) = tokenAttr(tokenIdx);
    tokenSize(0) = tokenSize(tokenIdx);
    tokenSymId(0) = tokenSymId(tokenIdx);
    if HaveTokens then
        tokenIdx = tokenIdx - 1;
end;



/* nest - sw = 1 -> nest macro sw = 2 -> nest if */
Nest: procedure(sw) public;
    declare sw byte;
$IF MACRO
    macroCondStk(macroCondSP := macroCondSP + 1) = macroCondStk(0);
    /* record whether current nest is macro of if */
    if (macroCondStk(0) := sw) = 1 then
    do;
        if (macroDepth := macroDepth + 1) > 9 then
        do;
            call StackError;
            macroDepth = 0;
        end;
        else
        do;
            call move(16, .macroStk(0), .macroStk(macroDepth));
            tmac$macroCondSP = macroCondSP;
            tmac$ifDepth = ifDepth;
            b9061 = TRUE;
        end;
    end;
    else
$ENDIF
    do;
        if (ifDepth := ifDepth + 1) > 8 then
        do;
            call StackError;
            ifDepth = 0;
        end;
        else
        do;
            skipIf(ifDepth) = skipIf(0);
            inElse(ifDepth) = inElse(0);
        end;
    end;
end;


UnNest: procedure(sw) public;
    declare sw byte;

$IF MACRO
    if sw <> macroCondStk(0) then	/* check for unbalanced unnest */
    do;
        call NestingError;
        if sw = 2 then			/* not macro unnest */
            return;
        macroCondSP = tmac$macroCondSP;
        ifDepth = tmac$ifDepth;
    end;

    macroCondStk(0) = macroCondStk(macroCondSP);	/* restore macro stack */
    macroCondSP = macroCondSP - 1;
    if sw = 1 then			/* is unnest macro */
    do;
        call move(16, .macroStk(macroDepth), .macroStk(0));
        call ReadM(tmac$blk);
        b9062 = tmac$mtype;
        if (macroDepth := macroDepth - 1) = 0 then	/* end of macro nest */
        do;
            expandingMacro = 0;		/* not expanding */
            baseMacroTbl = Physmem + 0BFh;
        end;
    end;
$ELSE
    if ifDepth = 0 then			/* nothing to unnest */
        call NestingError;
$ENDIF
    else
    do;
        skipIf(0) = skipIf(ifDepth);	/* pop skipIf and inElse status */
        inElse(0) = inElse(ifDepth);
        ifDepth = ifDepth - 1;
    end;
end;

PushToken: procedure(type) public;
    declare type byte;

    if tokenIdx >= 8 then
        call StackError;
    else
    do;
        tokenIdx = tokenIdx + 1;
        tokStart(tokenIdx) = tokStart(0);
        tokenSym(tokenIdx) = tokenSym(0);
        tokenType(tokenIdx) = tokenType(0);
        tokenAttr(tokenIdx) = tokenAttr(0);
        tokenSize(tokenIdx) = tokenSize(0);
        tokenSymId(tokenIdx) = tokenSymId(0);    
        tokStart(0) = tokStart(0) + tokenSize(0);    /* advance for next token */
        tokenType(0) = type;
        tokenAttr(0), tokenSize(0) = bZERO;
        tokenSym(0) = wZERO;
$IF MACRO
        tokenSymId(0) = wZERO;
$ELSE
        tokenSymId(0) = tokenSym(0);
$ENDIF
    end;
end;

CollectByte: procedure(c) public;
    declare c byte;
    declare s pointer;
    declare ch based s byte;


    if (s := tokPtr + tokenSize(0)) < endLineBuf then    /* check for lineBuf overrun */
    do;
        ch = c;
        tokenSize(0) = tokenSize(0) + 1;
    end;
    else
        call StackError;
end;

GetId: procedure(type) public;
    declare type byte;

    call PushToken(type);    /* save any previous token and initialise this one */
    reget = 1;        /* force re get of first character */

    do while (type := GetChClass) = CC$DIG or type = CC$LET;    /* digit or letter */
        if curChar > 60h then    /* make sure upper case */
            curChar = curChar and 0DFh;
        call CollectByte(curChar);
    end;
    reget = 1;        /* force re get of Exit char */
end;


GetNum: procedure public;
    declare accum address,
        (radix, digit, i) byte;
    declare chrs based tokPtr (1) byte;

    call GetId(O$NUMBER);
    radix = chrs(tokenSize(0):= tokenSize(0) - 1);
    if radix = 'H' then
        radix = 16;

    if radix = 'D' then
        radix = 10;

    if radix = 'O' or radix = 'Q' then
        radix = 8;

    if radix = 'B' then
        radix = 2;

    if radix > 16 then
        radix = 10;
    else
        tokenSize(0)= tokenSize(0) - 1;

    accum = 0;
    do i = 0 to tokenSize(0);
        if chrs(i) = '?' or chrs(i) = '@' then
        do;
            call IllegalCharError;
            digit = 0;
        end;
        else
        do;
            if (digit := chrs(i) - '0') > 9 then
                digit = digit - 7;
            if digit >= radix then
                if not (tokenType(2) = 40h) then /* risk that may be uninitialised */
                do;
                    call IllegalCharError;
                    digit = 0;
                end;
        end;

        accum = accum * radix + digit;
    end;
    /* replace with packed number */
    tokenSize(0) = 0;
    call CollectByte(low(accum));
    call CollectByte(high(accum));
end;

GetStr: procedure public;
    call PushToken(O$STRING);

    do while GetCh <> CR;
        if curChar = '''' then
            if GetCh <> '''' then
                goto L6268;
        call CollectByte(curChar);
    end;

    call BalanceError;

L6268:
    reget = 1;
end;

end;
