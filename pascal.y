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

    void freeAST(struct AST * expr);
    struct AST * makePrimary(char type, int left);
    struct AST * makeSingleWithValue(char type, int value, struct AST * ast);
    struct AST * makeAST(char type, struct AST * left, struct AST * right);
    struct AST * makeASTWithValue(char type, int value, struct AST * left, struct AST * right);
    struct AST * appendAST(struct AST * list, struct AST * stmt);
    int eval(struct AST * expr);
%}

%define api.prefix {pascal}

%union
{
    int ival;
    char * sval;
    struct AST * astval;
}

%token <sval> IDENTIFIER
%token <ival> NUM
%token VAR INTEGER
%token PROGRAM BEGIN_BLOCK END_BLOCK
%token PERIOD SEMICOLON COLON LEFT_PAREN RIGHT_PAREN COMMA
%token ASSIGN GREATER_THAN LESS_THAN PLUS MINUS MULT DIV
%token IF THEN ELSE WHILE DO

%right THEN ELSE

%type <astval> primary_expression multiplicative_expression additive_expression expression
%type <astval> control_flow statement statement_list block1 block
%type <sval> variable procid

%%
pascal_program: PROGRAM IDENTIFIER SEMICOLON block PERIOD                       {
                                                                                  printf("Parse Successful\n");
                                                                                  printf("Begin execution:\n");
                                                                                  eval($4);
                                                                                  freeAST($4);
                                                                                }
;

block: block1                                                                   {$$ = $1;}
| variable_declaration SEMICOLON block1                                         {$$ = $3;}
;

block1: BEGIN_BLOCK statement_list END_BLOCK                                    {
                                                                                  printf("Main block\n");
                                                                                  $$ = $2;
                                                                                }
;

variable_declaration: VAR variableid_list COLON INTEGER
| variable_declaration SEMICOLON variableid_list COLON INTEGER
;

variableid_list: IDENTIFIER                                                     {printf("Variable declaration=%s\n", $1);}
| variableid_list COMMA IDENTIFIER                                              {printf("Variable declaration=%s\n", $3);}
;

statement_list: statement                                                       {$$ = makeAST('l', $1, NULL);}
| statement_list SEMICOLON statement                                            {
                                                                                  appendAST($1, makeAST('l', $3, NULL));
                                                                                }
;

statement:                                                                      {
                                                                                  printf("Empty statement\n");
                                                                                  $$ = makeAST('e', NULL, NULL);
                                                                                }
| variable ASSIGN expression                                                    {
                                                                                  printf("Assignment statement\n");
                                                                                  $$ = makeSingleWithValue('=', $1[0], $3);
                                                                                }
| BEGIN_BLOCK statement_list END_BLOCK                                          {printf("Code block\n"); $$ = $2;}
| control_flow                                                                  {$$ = $1;}
| procid LEFT_PAREN expression RIGHT_PAREN                                      {
                                                                                  printf("Function with parameters=%s\n", $1);

                                                                                  // I guess negative characters are a thing
                                                                                  if (strcmp("writeln", $1) == -'(')
                                                                                  {
                                                                                    $$ = makeAST('p', $3, NULL);
                                                                                  }
                                                                                  else
                                                                                  {
                                                                                    yyerror("Function not recognized");
                                                                                  }
                                                                                }
;

control_flow: IF expression THEN statement                                      {
                                                                                  printf("If statement\n");
                                                                                  $$ = makeSingleWithValue('i', eval($2), $4);
                                                                                  freeAST($2);
                                                                                }
| IF expression THEN statement ELSE statement                                   {
                                                                                  printf("If-else statement\n");
                                                                                  $$ = makeASTWithValue('i', eval($2), $4, $6);
                                                                                  freeAST($2);
                                                                                }
| WHILE expression DO statement                                                 {
                                                                                  printf("While statement\n");
                                                                                  $$ = makeAST('w', $2, $4);
                                                                                }
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
                                                                                  $$ = makePrimary('n', $1);
                                                                                }
;

procid: IDENTIFIER                                                              {$$ = $1;}
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

struct AST * makeSingleWithValue(char type, int value, struct AST * ast)
{
  struct AST * stmt = makeASTWithValue(type, value, ast, NULL);

  return stmt;
}

struct AST * makeAST(char type, struct AST * left, struct AST * right)
{
  struct AST * expr = malloc(sizeof(struct AST));
  expr->type = type;
  expr->left = left;
  expr->right = right;

  return expr;
}

struct AST * makeASTWithValue(char type, int value, struct AST * left, struct AST * right)
{
  struct AST * expr = malloc(sizeof(struct AST));
  expr->type = type;
  expr->value = value;
  expr->left = left;
  expr->right = right;

  return expr;
}

struct AST * appendAST(struct AST * list, struct AST * stmt)
{
  struct AST * tail = list;
  while(tail->right != NULL)
  {
    tail = tail->right;
  }

  tail->right = stmt;
}

int eval(struct AST * expr)
{
  int result = 0;

  if (expr != NULL)
  {
    /* printf("Current: %c, Value: %d\n", expr->type, expr->value); */
    switch (expr->type)
    {
      //Primary value-holders
      case 'n': result = expr->value;
      break;
      case 'v': result = getValue(expr->value)[1];
      break;

      //Expressions
      case '>': result = eval(expr->left) > eval(expr->right);
      break;
      case '<': result = eval(expr->left) < eval(expr->right);
      break;
      case '+': result = eval(expr->left) + eval(expr->right);
      break;
      case '-': result = eval(expr->left) - eval(expr->right);
      break;
      case '*': result = eval(expr->left) * eval(expr->right);
      break;
      case '/': result = eval(expr->left) / eval(expr->right);
      break;

      //Statements
      case '=':
        result = eval(expr->left);
        assign(expr->value, result);
      break;
      case 'p':
        printf("%d\n", eval(expr->left));
      break;
      case 'i':
        if (eval(expr->left))
        {
          result = 1;
          eval(expr->left);
        }
        else
        {
          eval(expr->right);
        }
      break;
      case 'w':
        while(eval(expr->left))
        {
          eval(expr->right);
        }
      break;
      case 'l':
        eval(expr->left);
        eval(expr->right);
      break;
    }
  }

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
