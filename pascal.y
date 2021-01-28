%{
		#include <stdio.h>

    int yylex();
    int yyerror(const char *s);
    int yyparse();
%}

%define api.prefix {pascal}

%union
{
    char *sval;
}

%token IDENTIFIER
%token <sval> STRING
%token EOL
%token PROGRAM BEGIN_BLOCK END_BLOCK
%token '(' ')' ';' '.'

%%
pascal_program: PROGRAM IDENTIFIER program_heading ';' block '.'

program_heading:

block: block1

block1: block2

block2: block3

block3: block4

block4: block5

block5: BEGIN_BLOCK statement_list END_BLOCK

statement_list: statement
| statement_list ';' statement

statement: empty
| procid
| procid '(' expression_list ')'
;

expression_list: expression
| expression_list ',' expression
;

expression: additive_expression

additive_expression: multiplicative_expression

multiplicative_expression: unary_expression

unary_expression: primary_expression

primary_expression: STRING

procid: IDENTIFIER

empty:
%%

int main()
{
	yyparse();
	return 0;
}

int yyerror(const char * s)
{
  return -1;
}
