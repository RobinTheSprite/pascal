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

    struct AST
    {
      // Interpretable things:
      // - Assignment
      // - If-then
      // - If-then-else
      // - While
      // - function (print)
    };

    struct Expression
    {
      char type;
      int value;
      struct Expression * left;
      struct Expression * right;
    };

    #define symbolLength 100
    extern struct Symbol symbols[symbolLength];
    int * getValue(char symbol);
    void assign(char, int value);
    void evalStatement();
    void freeExpression(struct Expression * expr);
    struct Expression * makePrimary(char type, int left);
    struct Expression * makeExpression(char type, struct Expression * left, struct Expression * right);
    int evalExpression(struct Expression * expr);
%}

%define api.prefix {pascal}

%union
{
    int ival;
    char * sval;
    struct Expression * exprval;
}

%token <sval> IDENTIFIER
%token <ival> NUM
%token VAR INTEGER
%token PROGRAM BEGIN_BLOCK END_BLOCK
%token PERIOD SEMICOLON COLON LEFT_PAREN RIGHT_PAREN COMMA
%token ASSIGN GREATER_THAN LESS_THAN PLUS MINUS MULT DIV
%token IF THEN ELSE WHILE DO

%right THEN ELSE

%type <exprval> primary_expression multiplicative_expression additive_expression expression
%type <sval> variable procid

%%
pascal_program: PROGRAM IDENTIFIER SEMICOLON block PERIOD       {printf("Parse Successful\n");}
;

block: block1
| variable_declaration SEMICOLON block1
;

block1: BEGIN_BLOCK statement_list END_BLOCK                                    {printf("Main block\n");}
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
                                                                                  int result = evalExpression($3);
                                                                                  printf("Assignment statement %c=%d\n", $1[0], result);
                                                                                  assign($1[0], result);
                                                                                  freeExpression($3);
                                                                                }
| BEGIN_BLOCK statement_list END_BLOCK                                          {printf("Code block\n");}
| control_flow
| procid LEFT_PAREN expression RIGHT_PAREN                                      {
                                                                                  printf("Function with parameters=%s\n", $1);
                                                                                  // I guess negative characters are a thing
                                                                                  if (strcmp("writeln", $1) == -'(')
                                                                                  {
                                                                                    printf("%d\n", evalExpression($3));
                                                                                  }

                                                                                  freeExpression($3);
                                                                                }
;

control_flow: IF expression THEN statement                                      {printf("If statement=%d\n", evalExpression($2)); freeExpression($2);}
| IF expression THEN statement ELSE statement                                   {printf("If-else statement=%d\n", evalExpression($2)); freeExpression($2);}
| WHILE expression DO statement                                                 {printf("While statement=%d\n", evalExpression($2)); freeExpression($2);}
;

variable: IDENTIFIER                                                            {printf("Variable=%c\n", $1[0]); $$ = $1;}
;

expression: expression GREATER_THAN additive_expression                         {
                                                                                  $$ = makeExpression('>', $3, $1);
                                                                                  printf("Greater than\n");
                                                                                }
| expression LESS_THAN additive_expression                                      {
                                                                                  $$ = makeExpression('<', $3, $1);
                                                                                  printf("Less than\n");
                                                                                }
| additive_expression                                                           {
                                                                                  printf("Expression\n");
                                                                                  $$ = $1;
                                                                                }
;

additive_expression: additive_expression PLUS multiplicative_expression         {
                                                                                  printf("Addition\n");
                                                                                  $$ = makeExpression('+', $3, $1);
                                                                                }
| additive_expression MINUS multiplicative_expression                           {
                                                                                  printf("Subtraction\n");
                                                                                  $$ = makeExpression('-', $3, $1);
                                                                                }
| multiplicative_expression                                                     {$$ = $1;}
;

multiplicative_expression: multiplicative_expression MULT primary_expression      {
                                                                                    printf("Multiplication\n");
                                                                                    struct Expression expr;
                                                                                    $$ = makeExpression('*', $3, $1);
                                                                                  }
| multiplicative_expression DIV primary_expression                                {
                                                                                    printf("Division\n");
                                                                                    $$ = makeExpression('/', $3, $1);
                                                                                  }
| primary_expression                                                              {$$ = $1;}
;

primary_expression: variable                                                    {
                                                                                  int * result = getValue($1[0]);
                                                                                  if (result[0] == 0)
                                                                                  {
                                                                                    $$ = makePrimary('v', $1[0]);
                                                                                  }
                                                                                  else
                                                                                  {
                                                                                    yyerror("Variable not found");
                                                                                  }
                                                                                }
| NUM                                                                           {
                                                                                  printf("Integer=%d\n", $1);
                                                                                  $$ = makePrimary('i', $1);
                                                                                }
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

int * getValue(char symbol)
{
  static int result[2];
  for (int i = 0; i < symbolLength; ++i)
  {
    if (symbols[i].name == symbol)
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

void freeExpression(struct Expression * expr)
{
  if (expr->left != NULL)
  {
    freeExpression(expr->left);
  }

  if (expr->right != NULL)
  {
    freeExpression(expr->right);
  }

  free(expr);
  printf("Free\n");
}

struct Expression * makePrimary(char type, int left)
{
  struct Expression * expr = malloc(sizeof(struct Expression));
  printf("Malloc\n");
  expr->type = type;
  expr->value = left;
  expr->left = NULL;
  expr->right = NULL;

  return expr;
}

struct Expression * makeExpression(char type, struct Expression * left, struct Expression * right)
{
  struct Expression * expr = malloc(sizeof(struct Expression));
  printf("Malloc\n");
  expr->type = type;
  expr->left = left;
  expr->right = right;

  return expr;
}

int evalExpression(struct Expression * expr)
{
  switch (expr->type)
  {
    case 'i': return expr->value;
    break;
    case 'v': return getValue(expr->value)[1];
    break;
    case '>': return evalExpression(expr->left) > evalExpression(expr->right);
    break;
    case '<': return evalExpression(expr->left) > evalExpression(expr->right);
    break;
    case '+': return evalExpression(expr->left) + evalExpression(expr->right);
    break;
    case '-': return evalExpression(expr->left) - evalExpression(expr->right);
    break;
    case '*': return evalExpression(expr->left) * evalExpression(expr->right);
    break;
    case '/': return evalExpression(expr->left) / evalExpression(expr->right);
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
