%{
		#include <stdio.h>

    int yylex();
    int yyerror(const char *s);
    int yyparse();
%}

%define api.prefix {pascal}

%union
{
    int ival;
}

%token IDENTIFIER
%token <ival> NUM
%token VAR
%token PROGRAM BEGIN_BLOCK END_BLOCK
%token PERIOD SEMICOLON LEFT_PAREN RIGHT_PAREN COMMA
%token ASSIGN GREATER_THAN LESS_THAN

%%
pascal_program: PROGRAM IDENTIFIER program_heading SEMICOLON block PERIOD {printf("Parse Successful\n");}
;

program_heading:
| LEFT_PAREN identifier_list RIGHT_PAREN
;

identifier_list: IDENTIFIER                                               {printf("Identifier list\n");}
| identifier_list COMMA IDENTIFIER                                        {printf("Identifier list\n");}
;

block: block1
;

block1: block2
;

block2: block3
| variable_declaration SEMICOLON block4
;

block3: block4
;

block4: block5
;

block5: BEGIN_BLOCK statement_list END_BLOCK                      {printf("Begin/end block\n");}
;

variable_declaration: VAR variableid_list
| variable_declaration SEMICOLON variableid_list
;

variableid_list: IDENTIFIER                                       {printf("Variable list\n");}
| variableid_list COMMA IDENTIFIER
;

statement_list: statement                                         {printf("Statement\n");}
| statement_list SEMICOLON statement                              {printf("Statement list\n");}
;

statement: empty                                                  {printf("Empty statement\n");}
| IDENTIFIER ASSIGN expression                                    {printf("Assignment statement\n");}
| procid                                                          {printf("Zero parameter function\n");}
| procid LEFT_PAREN expression_list RIGHT_PAREN                   {printf("Function with parameters\n");}
;

expression_list: expression                                       {printf("expression\n");}
| expression_list COMMA expression                                {printf("Expression list\n");}
;

expression: expression relational_op additive_expression
| additive_expression
;

relational_op: GREATER_THAN                                       {printf("Greater than\n");}
| LESS_THAN                                                       {printf("Less than\n");}
;

additive_expression: multiplicative_expression
;

multiplicative_expression: unary_expression
;

unary_expression: primary_expression
;

primary_expression: NUM                                           {printf("Integer=%d\n", $1);}
;

procid: IDENTIFIER                                                {printf("ID\n");}
;

empty:
;
%%

int main()
{
	yyparse();
	return 0;
}

int yyerror(const char * s)
{
	fprintf(stderr, "Parse error: %s\n", s);
  return -1;
}
