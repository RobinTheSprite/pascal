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
      char type;
      int value;
      struct AST * left;
      struct AST * right;
    };

    #define symbolLength 100
    extern struct Symbol symbols[symbolLength];
    int * getValue(char symbol);
    void assign(char, int value);
    void evalStatement();
    void freeAST(struct AST * expr);
    struct AST * makePrimary(char type, int left);
    struct AST * makeAST(char type, struct AST * left, struct AST * right);
    int eval(struct AST * expr);
%}

%define api.prefix {pascal}

%union
{
    int ival;
    char * sval;
    struct AST * exprval;
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

variableid_list: IDENTIFIER                                                     {printf("Variable declaration=%s\n", $1);}
| variableid_list COMMA IDENTIFIER                                              {printf("Variable declaration=%s\n", $3);}
;

statement_list: statement
| statement_list SEMICOLON statement
;

statement:                                                                      {printf("Empty statement\n");}
| variable ASSIGN expression                                                    {
                                                                                  int result = eval($3);
                                                                                  printf("Assignment statement %c=%d\n", $1[0], result);
                                                                                  assign($1[0], result);
                                                                                  freeAST($3);
                                                                                }
| BEGIN_BLOCK statement_list END_BLOCK                                          {printf("Code block\n");}
| control_flow
| procid LEFT_PAREN expression RIGHT_PAREN                                      {
                                                                                  printf("Function with parameters=%s\n", $1);
                                                                                  // I guess negative characters are a thing
                                                                                  if (strcmp("writeln", $1) == -'(')
                                                                                  {
                                                                                    printf("%d\n", eval($3));
                                                                                  }

                                                                                  freeAST($3);
                                                                                }
;

control_flow: IF expression THEN statement                                      {printf("If statement=%d\n", eval($2)); freeAST($2);}
| IF expression THEN statement ELSE statement                                   {printf("If-else statement=%d\n", eval($2)); freeAST($2);}
| WHILE expression DO statement                                                 {printf("While statement=%d\n", eval($2)); freeAST($2);}
;

variable: IDENTIFIER                                                            {printf("Variable=%c\n", $1[0]); $$ = $1;}
;

expression: expression GREATER_THAN additive_expression                         {
                                                                                  $$ = makeAST('>', $1, $3);
                                                                                  printf("Greater than\n");
                                                                                }
| expression LESS_THAN additive_expression                                      {
                                                                                  $$ = makeAST('<', $1, $3);
                                                                                  printf("Less than\n");
                                                                                }
| additive_expression                                                           {
                                                                                  $$ = $1;
                                                                                }
;

additive_expression: additive_expression PLUS multiplicative_expression         {
                                                                                  printf("Addition\n");
                                                                                  $$ = makeAST('+', $1, $3);
                                                                                }
| additive_expression MINUS multiplicative_expression                           {
                                                                                  printf("Subtraction\n");
                                                                                  $$ = makeAST('-', $1, $3);
                                                                                }
| multiplicative_expression                                                     {$$ = $1;}
;

multiplicative_expression: multiplicative_expression MULT primary_expression      {
                                                                                    printf("Multiplication\n");
                                                                                    struct AST expr;
                                                                                    $$ = makeAST('*', $1, $3);
                                                                                  }
| multiplicative_expression DIV primary_expression                                {
                                                                                    printf("Division\n");
                                                                                    $$ = makeAST('/', $1, $3);
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

void freeAST(struct AST * expr)
{
  if (expr->left != NULL)
  {
    freeAST(expr->left);
  }

  if (expr->right != NULL)
  {
    freeAST(expr->right);
  }

  free(expr);
}

struct AST * makePrimary(char type, int left)
{
  struct AST * expr = malloc(sizeof(struct AST));
  expr->type = type;
  expr->value = left;
  expr->left = NULL;
  expr->right = NULL;

  return expr;
}

struct AST * makeAST(char type, struct AST * left, struct AST * right)
{
  struct AST * expr = malloc(sizeof(struct AST));
  expr->type = type;
  expr->left = left;
  expr->right = right;

  return expr;
}

int eval(struct AST * expr)
{
  switch (expr->type)
  {
    case 'i': return expr->value;
    break;
    case 'v': return getValue(expr->value)[1];
    break;
    case '>': return eval(expr->left) > eval(expr->right);
    break;
    case '<': return eval(expr->left) > eval(expr->right);
    break;
    case '+': return eval(expr->left) + eval(expr->right);
    break;
    case '-': return eval(expr->left) - eval(expr->right);
    break;
    case '*': return eval(expr->left) * eval(expr->right);
    break;
    case '/': return eval(expr->left) / eval(expr->right);
    break;
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
