%option noyywrap
%option prefix="pascal"

%{
		#include <stdio.h>
    #include "pascal.tab.h"

    int yylex();
%}

%%
program                               {return (PROGRAM);}
begin                                 {return (BEGIN_BLOCK);}
end                                   {return (END_BLOCK);}
([a-zA-Z]|_)[a-zA-Z0-9]{1,127}        {return (IDENTIFIER);}
'.*'                                  {return (STRING);}
[ \n\t.;]                             {}
.                                     {printf("Unknown character %c\n", *yytext);}
%%
