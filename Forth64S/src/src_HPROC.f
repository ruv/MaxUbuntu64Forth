
\- DOCREATE	: DOCREATE	R> ;
\- DOCONSTANT	: DOCONSTANT	R> @ ;
\- DOVALUE	: DOTVALUE	R> @ ;
\- DOVECT 	: DOVECT	R> PERFORM ;
\- DOFIELD	: DOFIELD	R> L@ + ;

' DOCONSTANT TO 'DOCONSTANT
' DOVALUE TO 'DOVALUE
' DOVECT TO 'DOVECT
' DOFIELD TO 'DOFIELD

VARIABLE SP0
VARIABLE &INPUT
VARIABLE &INPUT?

VARIABLE &OUTPUT

1 VALUE H-STDOUT

CREATE &START_INIT ' NOOP ,
CREATE DP ' DPBuff ,
CREATE CODE-LIMIT ' _Stekc ,

VARIABLE EMITVAR

T: THERE DP @ ;

T: ALLOT DP +! ;

T: DP! DP ! ;

T: ,   THERE ! 8 ALLOT ;

T: L, THERE L! 4 ALLOT ;

T: W, THERE W! 2 ALLOT ;

T: C, THERE C! 1 ALLOT ;

: TYPE1 ( c-addr u -- ) \ 94
 H-STDOUT  WRITE-FILE DROP
;

' TYPE1 ->DEFER TYPE

:  EMIT1  SP@ 1 TYPE DROP ;

' EMIT1 ->defer EMIT


: CR1	$a EMIT ;
' CR1 ->defer CR

: TAB	9  EMIT ;

T: HALIGNED  1+  1 ANDC ;
T: IALIGNED  3 + 3 ANDC ;
T: ALIGNED   7 + 7 ANDC ;

: (S")  ( --- c-addr u )
\ Runtime part of S"
\ It returns address and length of an in-line counted string.
  R>  COUNT 2DUP + >R ;

\+ '(S") ' (S") TO '(S")

: (C")  ( --- c-addr )
   R> DUP COUNT +  >R ;

\+ '(C") ' (C") TO '(C")

: (Z")  ( --- z-addr )
\ Runtime part of Z"
\ It returns address of an 0 terminated string.
   R>  COUNT  OVER +  >R ;

' (Z") TO '(Z")

: DEPTH ( -- n ) \ 94
  SP@ SP0 @ - NEGATE  3 ARSHIFT ;

\ T: ERASE 0 FILL ;

: SPACE BL EMIT ;

: 0MAX 0 MAX ;

: 3DUP DUP 2OVER ROT ;

: CS-ROLL  2* 1+ DUP>R ROLL R> ROLL ;

: D2*      ( D -- D*2 )        2DUP D+     ;
: DABS     ( d -- ud )         DUP 0< IF DNEGATE THEN  ;

: U/MOD 0 SWAP UM/MOD ;

\ : U/ ( n1 n2 -- n1*n2 ) U/MOD  NIP ;

\ : UMOD ( n1 n2 -- n1%n2 )  U/MOD DROP ;

: MOVE ( addr1 addr2 u -- ) \ 94	
  >R 2DUP SWAP R@ + U<
  IF 2DUP U<
     IF R> CMOVE> ELSE R> CMOVE THEN
  ELSE R> CMOVE THEN ;

\- MAX$@ $FF CONSTANT MAX$@

: "CLIP"        ( a1 n1 -- a1 n1' )   \ clip a string to between 0 and MAXCOUNTED
                0 MAX MAX$@ AND ( UMIN ) ;


: $!         ( addr len dest -- )
        SWAP "CLIP" SWAP
	2DUP C! CHAR+ SWAP CMOVE ;


: $+!       ( addr len dest -- ) \ append string addr,len to counted
                                     \ string dest
                >R "CLIP" MAX$@  R@ C@ -  MIN R>
                                        \ clip total to MAXCOUNTED string
	2DUP 2>R
	COUNT  + SWAP CMOVE
	2R> C+! ;


: $C+!       ( c1 a1 -- )    \ append char c1 to the counted string at a1
	DUP 1+!
 COUNT + 1- C! ;


: C+PLACE $C+! ;

: +NULL         ( a1 -- )       \ append a NULL just beyond the counted chars
                COUNT + 0 SWAP C! ;



: COMPARE ( addr1 u1 addr2 u2 --- diff )
\ Compare two strings. diff is negative if addr1 u1 is smaller, 0 if it
\ is equal and positive if it is greater than addr2 u2.

  ROT 2DUP - >R        
  MIN DUP IF
   >R
   BEGIN
    OVER C@ OVER C@ - IF
     SWAP C@ SWAP C@ -
		 2RDROP	EXIT
    THEN 
    1+ SWAP 1+ SWAP
    R> 1- DUP >R 0=
   UNTIL R>
  THEN DROP
  2DROP R> NEGATE
;


: SCAN ( c-addr1 u1 c --- c-addr2 u2 )
\ Find the first occurrence of character c in the string c-addr1 u1
\ c-addr2 u2 is the remaining part of the string starting with that char.
\ It is a zero-length string if c was not found.
  BEGIN
   OVER
  WHILE
   ROT DUP C@ >R OVER R> =
   IF -ROT DROP
   BREAK
   1+ -ROT SWAP 1- SWAP
  REPEAT DROP
;

: SEARCH ( c-addr1 u1 c-addr2 u2 -- c-addr3 u3 flag ) \ 94 STRING
    2>R 2DUP
    BEGIN
      DUP 1+ R@ >
    WHILE
      OVER 2R@ TUCK COMPARE 0=
      IF 2RDROP 2SWAP 2DROP TRUE EXIT THEN
      1- SWAP 1+ SWAP
    REPEAT 2RDROP 2DROP 0
;

: REL@ ( ADDR -- ADDR' )
         DUP SL@ + ;

: <'>
R>  1+ DUP 4 + >R  REL@ 4 + ;

T: >BODY 5 + ;

$20 CONSTANT BL
8 CONSTANT CELL
0 CONSTANT FALSE
-1 CONSTANT TRUE


: CATCH ( i*x xt -- j*x 0 | i*x n ) \ 94 EXCEPTION
\ Положить на стек исключений кадр перехвата исключительных ситуаций
\ и выполнить токен xt (как по EXECUTE) таким образом, чтобы управление
\ могло быть передано в точку сразу после CATCH, если во время выполнения
\ xt выполняется THROW.
\ Если выполнение xt заканчивается нормально (т.е. кадр исключений,
\ положенный на стек словом CATCH не был взят выполнением THROW),
\ взять кадр исключений и вернуть ноль на вершину стека данных,
\ остальные элементы стека возвращаются xt EXECUTE. Иначе остаток
\ семантики выполнения дается THROW.
\  <SET-EXC-HANDLER>

  SP@ >R  HANDLER @  >R
  RP@ HANDLER !
  EXECUTE
  R> HANDLER !
  RDROP
  0
;

' CATCH TO 'CATCH

: THROW
\ Если любые биты n ненулевые, взять верхний кадр исключений со стека
\ исключений, включая все на стеке возвратов над этим кадром. Затем
\ восстановить спецификации входного потока, который использовался перед
\ соответствующим CATCH, и установить глубины всех стеков, определенных
\ в этом Стандарте, в то состояние, которое было сохранено в кадре
\ исключений (i - это то же число, что и i во входных аргументах
\ соответствующего CATCH), положить n на вершину стека данных и передать
\ управление в точку сразу после CATCH, которое положило этот кадр
\ исключений.
\ Если вершина стека не ноль, и на стеке исключений есть кадр 
\ исключений, то поведение следующее:
\   Если n=-1, выполнить функцию ABORT (версию ABORT из слов CORE), 
\   не выводя сообщений.
\   Если n=-2, выполнить функцию ABORT" (версию ABORT" из слов CORE), 
\   выводя символы ccc, ассоциированные с ABORT", генерирующим THROW.
\   Иначе система может вывести на дисплей зависящее от реализации 
\   сообщение об условии, соответствующем THROW с кодом n. Затем 
\   система выполнит функцию ABORT (версию ABORT из CORE).
  ?DUP
  IF
   ( SAVEERR )  HANDLER @ \ A@ 
     ?DUP
     IF
      RP!
        R> HANDLER !
        R> SWAP >R
        SP! DROP R>
     ELSE
\ FATAL-HANDLER
 THEN
  THEN
;

' THROW TO 'THROW 

T: ABORT -1 THROW ;

: ?THROW        \ k*x flag throw-code -- k*x|i*x n
\ *G Perform a *\fo{THROW} of value *\i{throw-code} if flag is non-zero.
  SWAP IF THROW THEN DROP
;

\ DEFER H.

: SHORT? ( n -- -129 < n < 128 )
  0x80 + 0x100 U< ;

: LONG? ( n -- -2147483648<n<2147483647 )
	$80000000 + $100000000 U< ;

: HH.
  DUP 0xF ANDC
  IF DUP 0xF AND >R
	4 RSHIFT
	T_RECURSE R>
  THEN
    DUP 10 < 0= IF 7 + THEN 48 + EMIT
;

: TTST ( N ADDR -- ) \ dtston
\	DTSTON
        SWAP OVER CR
	OR IF THEN
	OR 0= IF THEN
	3 cells
	DUP 0< IF THEN ;
