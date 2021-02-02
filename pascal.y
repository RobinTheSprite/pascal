%{
		#include <stdio.h>

    extern int yylex();
    int yyerror(const char *s);

    struct Symbol
    {
      char name;
      int value;
    };

    #define symbolLength 100
    extern struct Symbol symbols[100];
    void assign(char, int value);
%}

%define api.prefix {pascal}

%union
{
    int ival;
    char * sval;
}

%token <sval> IDENTIFIER
%token <ival> NUM
%token VAR
%token PROGRAM BEGIN_BLOCK END_BLOCK
%token PERIOD SEMICOLON LEFT_PAREN RIGHT_PAREN COMMA
%token ASSIGN GREATER_THAN LESS_THAN PLUS MINUS MULT DIV
%token IF THEN ELSE WHILE DO

%right THEN ELSE

%type <ival> primary_expression unary_expression multiplicative_expression additive_expression expression

%%
pascal_program: PROGRAM IDENTIFIER program_heading SEMICOLON block PERIOD       {printf("Parse Successful\n");}
;

program_heading:
| LEFT_PAREN identifier_list RIGHT_PAREN
;

identifier_list: IDENTIFIER                                                     {printf("Identifier list\n");}
| identifier_list COMMA IDENTIFIER                                              {printf("Identifier list\n");}
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

block5: BEGIN_BLOCK statement_list END_BLOCK                                    {printf("Begin/end block\n");}
;

variable_declaration: VAR variableid_list
| variable_declaration SEMICOLON variableid_list
;

variableid_list: IDENTIFIER                                                     {printf("Variable=%s\n", $1);}
| variableid_list COMMA IDENTIFIER                                              {printf("Variable=%s\n", $3);}
;

statement_list: statement                                                       {printf("Statement\n");}
| statement_list SEMICOLON statement                                            {printf("Statement list\n");}
;

statement: empty                                                                {printf("Empty statement\n");}
| IDENTIFIER ASSIGN expression                                                  {printf("Assignment statement %c=%d\n", $1[0], $3); assign($1[0], $3);}
| BEGIN_BLOCK statement_list END_BLOCK
| control_flow
| procid LEFT_PAREN expression_list RIGHT_PAREN                                 {printf("Function with parameters\n");}
;

control_flow: IF expression THEN statement                                      {printf("If statement\n");}
| IF expression THEN statement ELSE statement                                   {printf("If-else statement\n");}
| WHILE expression DO statement                                                 {printf("While statement\n");}
;

expression_list: expression
| expression_list COMMA expression                                              {printf("Expression list\n");}
;

expression: expression GREATER_THAN additive_expression                         {$$ = $1 > $3; printf("Greater than=%d\n", $$);}
| expression LESS_THAN additive_expression                                      {$$ = $1 < $3; printf("Less than=%d\n", $$);}
| additive_expression                                                           {printf("Expression=%d\n", $1); $$ = $1;}
;

additive_expression: additive_expression PLUS multiplicative_expression         {printf("Addition\n"); $$ = $1 + $3;}
| additive_expression MINUS multiplicative_expression                           {printf("Subtraction\n"); $$ = $1 - $3;}
| multiplicative_expression                                                     {$$ = $1;}
;

multiplicative_expression: multiplicative_expression MULT unary_expression      {printf("Multiplication\n"); $$ = $1 * $3;}
| multiplicative_expression DIV unary_expression                                {printf("Division\n"); $$ = $1 / $3;}
| unary_expression                                                              {$$ = $1;}
;

unary_expression: primary_expression                                            {$$ = $1;}
;

primary_expression: NUM                                                         {printf("Integer=%d\n", $1); $$ = $1;}
;

procid: IDENTIFIER                                                              {printf("ID\n");}
;

empty:
;
%%

void assign(char symbol, int value)
{
  for (int i = 0; i < symbolLength; ++i)
  {
    if (symbols[i].name == symbol)
    {
      symbols[i].value = value;
    }
  }
}

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
