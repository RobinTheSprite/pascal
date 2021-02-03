%{
		#include <stdio.h>
    #include <string.h>

    extern int yylex();
    int yyerror(const char *s);

    struct Symbol
    {
      char name;
      int value;
    };

    #define symbolLength 100
    extern struct Symbol symbols[100];
    int * getValue(char * symbol);
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
%token VAR INTEGER
%token PROGRAM BEGIN_BLOCK END_BLOCK
%token PERIOD SEMICOLON COLON LEFT_PAREN RIGHT_PAREN COMMA
%token ASSIGN GREATER_THAN LESS_THAN PLUS MINUS MULT DIV
%token IF THEN ELSE WHILE DO

%right THEN ELSE

%type <ival> primary_expression multiplicative_expression additive_expression expression
%type <sval> variable procid

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
| variable_declaration SEMICOLON block1
;

block1: BEGIN_BLOCK statement_list END_BLOCK                                    {printf("Begin/end block\n");}
;

variable_declaration: VAR variableid_list COLON INTEGER
| variable_declaration SEMICOLON variableid_list COLON INTEGER
;

variableid_list: IDENTIFIER                                                     {printf("Variable=%s\n", $1);}
| variableid_list COMMA IDENTIFIER                                              {printf("Variable=%s\n", $3);}
;

statement_list: statement                                                       {printf("Statement\n");}
| statement_list SEMICOLON statement                                            {printf("Statement list\n");}
;

statement:                                                                      {printf("Empty statement\n");}
| variable ASSIGN expression                                                    {
                                                                                  printf("Assignment statement %c=%d\n", $1[0], $3);
                                                                                  assign($1[0], $3);
                                                                                }
| BEGIN_BLOCK statement_list END_BLOCK
| control_flow
| procid LEFT_PAREN expression RIGHT_PAREN                                      {
                                                                                  printf("Function with parameters=%s\n", $1);
                                                                                  // I guess negative characters are a thing
                                                                                  if (strcmp("writeln", $1) == -'(')
                                                                                  {
                                                                                    printf("%d\n", $3);
                                                                                  }
                                                                                }
;

control_flow: IF expression THEN statement                                      {printf("If statement=%d\n", $2);}
| IF expression THEN statement ELSE statement                                   {printf("If-else statement=%d\n", $2);}
| WHILE expression DO statement                                                 {printf("While statement=%d\n", $2);}
;

variable: IDENTIFIER                                                            {printf("Variable=%c\n", $1[0]); $$ = $1;}
;

expression: expression GREATER_THAN additive_expression                         {$$ = $1 > $3; printf("Greater than=%d\n", $$);}
| expression LESS_THAN additive_expression                                      {$$ = $1 < $3; printf("Less than=%d\n", $$);}
| additive_expression                                                           {printf("Expression=%d\n", $1); $$ = $1;}
;

additive_expression: additive_expression PLUS multiplicative_expression         {printf("Addition\n"); $$ = $1 + $3;}
| additive_expression MINUS multiplicative_expression                           {printf("Subtraction\n"); $$ = $1 - $3;}
| multiplicative_expression                                                     {$$ = $1;}
;

multiplicative_expression: multiplicative_expression MULT primary_expression      {printf("Multiplication\n"); $$ = $1 * $3;}
| multiplicative_expression DIV primary_expression                                {printf("Division\n"); $$ = $1 / $3;}
| primary_expression                                                              {$$ = $1;}
;

primary_expression: variable                                                    {
                                                                                  int * result = getValue($1);
                                                                                  if (result[0] == 0)
                                                                                  {
                                                                                    $$ = result[1];
                                                                                  }
                                                                                  else
                                                                                  {
                                                                                    $$ = 0;
                                                                                  }
                                                                                }
| NUM                                                                           {printf("Integer=%d\n", $1); $$ = $1;}
;

procid: IDENTIFIER
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

int * getValue(char * symbol)
{
  static int result[2];
  for (int i = 0; i < symbolLength; ++i)
  {
    if (symbols[i].name == symbol[0])
    {
      result[0] = 0;
      result[1] = symbols[i].value;
      return result;
    }
  }

  result[0] = -1;
  result[1] = 0;
  return result;
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
