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
      int type;
      int value;
      struct AST * left;
      struct AST * right;
    };
    enum AST_Type
    {
      EMPTY,
      LIST,
      CONDITION,
      IF_ELSE,
      PROCEDURE
    };

    #define symbolLength 100
    extern struct Symbol symbols[symbolLength];
    int * getValue(char symbol);
    void assign(char symbol, int value);

    void freeAST(struct AST * ast);
    struct AST * makePrimary(int type, int left);
    struct AST * makeSingleWithValue(int type, int value, struct AST * ast);
    struct AST * makeAST(int type, struct AST * left, struct AST * right);
    struct AST * makeASTWithValue(int type, int value, struct AST * left, struct AST * right);
    struct AST * appendAST(struct AST * list, struct AST * stmt);
    int eval(struct AST * ast);
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

statement_list: statement                                                       {$$ = makeAST(LIST, $1, NULL);}
| statement_list SEMICOLON statement                                            {
                                                                                  appendAST($1, makeAST(LIST, $3, NULL));
                                                                                }
;

statement:                                                                      {
                                                                                  printf("Empty statement\n");
                                                                                  $$ = makeAST(EMPTY, NULL, NULL);
                                                                                }
| variable ASSIGN expression                                                    {
                                                                                  printf("Assignment statement\n");
                                                                                  $$ = makeSingleWithValue(ASSIGN, $1[0], $3);
                                                                                }
| BEGIN_BLOCK statement_list END_BLOCK                                          {printf("Code block\n"); $$ = $2;}
| control_flow                                                                  {$$ = $1;}
| procid LEFT_PAREN expression RIGHT_PAREN                                      {
                                                                                  printf("Function with parameters=%s\n", $1);

                                                                                  // I guess negative characters are a thing
                                                                                  if (strcmp("writeln", $1) == -'(')
                                                                                  {
                                                                                    $$ = makeAST(PROCEDURE, $3, NULL);
                                                                                  }
                                                                                  else
                                                                                  {
                                                                                    yyerror("Function not recognized");
                                                                                  }
                                                                                }
;

control_flow: IF expression THEN statement                                      {
                                                                                  printf("If statement\n");
                                                                                  $$ = makeAST(CONDITION, $2, makeAST(IF_ELSE, $4, NULL));
                                                                                }
| IF expression THEN statement ELSE statement                                   {
                                                                                  printf("If-else statement\n");
                                                                                  $$ = makeAST(CONDITION, $2, makeAST(IF_ELSE, $4, $6));
                                                                                }
| WHILE expression DO statement                                                 {
                                                                                  printf("While statement\n");
                                                                                  $$ = makeAST(WHILE, $2, $4);
                                                                                }
;

variable: IDENTIFIER                                                            {printf("Variable=%c\n", $1[0]); $$ = $1;}
;

expression: expression GREATER_THAN additive_expression                         {
                                                                                  $$ = makeAST(GREATER_THAN, $1, $3);
                                                                                  printf("Greater than\n");
                                                                                }
| expression LESS_THAN additive_expression                                      {
                                                                                  $$ = makeAST(LESS_THAN, $1, $3);
                                                                                  printf("Less than\n");
                                                                                }
| additive_expression                                                           {
                                                                                  $$ = $1;
                                                                                }
;

additive_expression: additive_expression PLUS multiplicative_expression         {
                                                                                  printf("Addition\n");
                                                                                  $$ = makeAST(PLUS, $1, $3);
                                                                                }
| additive_expression MINUS multiplicative_expression                           {
                                                                                  printf("Subtraction\n");
                                                                                  $$ = makeAST(MINUS, $1, $3);
                                                                                }
| multiplicative_expression                                                     {$$ = $1;}
;

multiplicative_expression: multiplicative_expression MULT primary_expression      {
                                                                                    printf("Multiplication\n");
                                                                                    $$ = makeAST(MULT, $1, $3);
                                                                                  }
| multiplicative_expression DIV primary_expression                                {
                                                                                    printf("Division\n");
                                                                                    $$ = makeAST(DIV, $1, $3);
                                                                                  }
| primary_expression                                                              {$$ = $1;}
;

primary_expression: variable                                                    {
                                                                                  int * result = getValue($1[0]);
                                                                                  if (result[0] == 0)
                                                                                  {
                                                                                    $$ = makePrimary(VAR, $1[0]);
                                                                                  }
                                                                                  else
                                                                                  {
                                                                                    yyerror("Variable not found");
                                                                                  }
                                                                                }
| NUM                                                                           {
                                                                                  printf("Integer=%d\n", $1);
                                                                                  $$ = makePrimary(NUM, $1);
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

void freeAST(struct AST * ast)
{
  if (ast->left != NULL)
  {
    freeAST(ast->left);
  }

  if (ast->right != NULL)
  {
    freeAST(ast->right);
  }

  free(ast);
}

struct AST * makePrimary(int type, int left)
{
  struct AST * ast = malloc(sizeof(struct AST));
  ast->type = type;
  ast->value = left;
  ast->left = NULL;
  ast->right = NULL;

  return ast;
}

struct AST * makeSingleWithValue(int type, int value, struct AST * ast)
{
  struct AST * stmt = makeASTWithValue(type, value, ast, NULL);

  return stmt;
}

struct AST * makeAST(int type, struct AST * left, struct AST * right)
{
  struct AST * ast = malloc(sizeof(struct AST));
  ast->type = type;
  ast->left = left;
  ast->right = right;

  return ast;
}

struct AST * makeASTWithValue(int type, int value, struct AST * left, struct AST * right)
{
  struct AST * ast = malloc(sizeof(struct AST));
  ast->type = type;
  ast->value = value;
  ast->left = left;
  ast->right = right;

  return ast;
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

int eval(struct AST * ast)
{
  int result = 0;

  if (ast != NULL)
  {
    /* printf("Current: %c, Value: %d Left: %c, Right: %c\n", ast->type, ast->value, left, right); */
    switch (ast->type)
    {
      //Primary value-holders
      case NUM: result = ast->value;
      break;
      case VAR: result = getValue(ast->value)[1];
      break;

      //Expressions
      case GREATER_THAN: result = eval(ast->left) > eval(ast->right);
      break;
      case LESS_THAN: result = eval(ast->left) < eval(ast->right);
      break;
      case PLUS: result = eval(ast->left) + eval(ast->right);
      break;
      case MINUS: result = eval(ast->left) - eval(ast->right);
      break;
      case MULT: result = eval(ast->left) * eval(ast->right);
      break;
      case DIV: result = eval(ast->left) / eval(ast->right);
      break;

      //Statements
      case ASSIGN:
        result = eval(ast->left);
        assign(ast->value, result);
      break;
      case PROCEDURE:
        printf("%d\n", eval(ast->left));
      break;
      case CONDITION:
        result = eval(ast->left);
        ast->right->value = result;
        eval(ast->right);
      break;
      case IF_ELSE:
        if (ast->value)
        {
          eval(ast->left);
        }
        else
        {
          eval(ast->right);
        }
      break;
      case WHILE:
        while(eval(ast->left))
        {
          eval(ast->right);
        }
      break;
      case LIST:
        eval(ast->left);
        eval(ast->right);
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
