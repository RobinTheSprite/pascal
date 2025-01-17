// pascal.y
// Mark Underwood
// March 2021

/*
  Creates a compiler that can compile a small subset of the Pascal
  language to LWIS (Large Width Instruction Set), an instruction set encoding
  of my own design.

  The compilation process is done in a single pass. The only language feature
  it does not compile from the Pascal subset is an if-else statement. No
  lifetime management is done when assigning temporary variables, so programs
  compiled with this version should consume fewer than 254.

  Many programming sins were committed to bring this compiler into being. Global
  variables, function side effects, and the use of malloc and free were all
  necessary to produce working code. Future iterations may improve.

  The only problem with the program at the time of presentation was a
  miscalculation of jump targets. The problem has since been corrected by
  inserting a placehoder value for instructions that need to be built after
  certain jump targets are calculated. The placeholder is replaced with the
  instruction once it is complete.
*/

%{
    #include <iostream>
    #include <iomanip>
    #include <fstream>
    #include <string>
    #include "string.h"
    #include <vector>

    // Flex/Bison related declarations
    extern int yylex();
    int yyerror(const char *s);

    // Represents a variable
    struct Symbol
    {
      char name = 0;
      int value = 0;
    };

    // A node of an Abstract Syntax Tree (AST)
    struct AST
    {
        int type = 0;
        int value = 0;
        AST * left;
        AST * right;
    };

    // Types of AST that are not covered by token types
    enum AST_Type
    {
      EMPTY,
      LIST,
      CONDITION,
      IF_ELSE,
      PROCEDURE
    };

    // Symbol table declarations
    #define NUM_OF_REGISTERS 254
    extern std::vector<Symbol> symbols;
    int * getValue(char symbol);
    void assign(char symbol, int value);

    // AST related declarations
    void freeAST(AST * ast);
    AST * makePrimary(int type, int left);
    AST * makeSingleWithValue(int type, int value, AST * ast);
    AST * makeAST(int type, AST * left, AST * right);
    AST * makeASTWithValue(int type, int value, AST * left, AST * right);
    void appendAST(AST * list, AST * stmt);
    int eval(AST * ast);

    // Compilation related declarations

    // What type an Operand can be
    enum ValueType
    {
      REGISTER,
      IMMEDIATE
    };

    // An operand to a statement or expression
    struct Operand
    {
      int value = 0;
      ValueType type = REGISTER;
    };
    int registerNumber(char symbol);
    int getTemporary();
    void addToInstruction(long & instruction, int value, int sizeOfValue);
    Operand createExpressionInstruction(AST * ast, int immediateOpcode, int immediateLayout, int registerOpcode, int registerLayout);
    Operand compile(AST * ast);

    // Stores the instructions that are compiled
    std::vector<long> program;
%}

%define api.prefix {pascal}

// The types used in the parser
%union
{
    int ival;
    char * sval;
    struct AST * astval;
}

// Tokens, organized by responsibility
%token <sval> IDENTIFIER
%token <ival> NUM
%token VAR INTEGER
%token PROGRAM BEGIN_BLOCK END_BLOCK
%token PERIOD SEMICOLON COLON LEFT_PAREN RIGHT_PAREN COMMA
%token ASSIGN GREATER_THAN LESS_THAN PLUS MINUS MULT DIV
%token IF THEN ELSE WHILE DO

// Solve the if-else shift-reduce problem
%right THEN ELSE

// Assign types to non-terminals that are returned as ASTs
%type <astval> primary_expression multiplicative_expression additive_expression expression
%type <astval> control_flow statement statement_list block1 block
%type <sval> variable procid

%%
pascal_program: PROGRAM IDENTIFIER SEMICOLON block PERIOD                       {
                                                                                  printf("Parse Successful\n");
                                                                                  printf("Begin compilation:\n");
                                                                                  compile($4);
                                                                                  freeAST($4);

                                                                                  for (auto instruction : program)
                                                                                  {
                                                                                    std::cout << std::hex << instruction << std::endl;
                                                                                  }

                                                                                  std::ofstream writer("pascal.lwis");
                                                                                  for (auto instruction : program)
                                                                                  {
                                                                                    writer << instruction << std::endl;
                                                                                  }
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

statement_list: statement                                                       {$$ = makeAST(LIST, $1, nullptr);}
| statement_list SEMICOLON statement                                            {
                                                                                  appendAST($1, makeAST(LIST, $3, nullptr));
                                                                                }
;

statement:                                                                      {
                                                                                  printf("Empty statement\n");
                                                                                  $$ = makeAST(EMPTY, nullptr, nullptr);
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
                                                                                    $$ = makeAST(PROCEDURE, $3, nullptr);
                                                                                  }
                                                                                  else
                                                                                  {
                                                                                    yyerror("Function not recognized");
                                                                                  }
                                                                                }
;

control_flow: IF expression THEN statement                                      {
                                                                                  printf("If statement\n");
                                                                                  $$ = makeAST(CONDITION, $2, makeAST(IF_ELSE, $4, nullptr));
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

// Assign a value to the given symbol
void assign(char symbol, int value)
{
  for (size_t i = 0; i < symbols.size(); ++i)
  {
    if (symbols[i].name == symbol)
    {
      symbols[i].value = value;
    }
  }
}

// Find the value associated with the given symbol
int * getValue(char symbol)
{
  static int result[2];
  for (size_t i = 0; i < symbols.size(); ++i)
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

// Free the nodes of the AST
void freeAST(AST * ast)
{
  if (ast->left != nullptr)
  {
    freeAST(ast->left);
  }

  if (ast->right != nullptr)
  {
    freeAST(ast->right);
  }

  free(ast);
}

// Make an AST representing a primary expression
AST * makePrimary(int type, int left)
{
  AST * ast = (AST *)malloc(sizeof(AST));
  ast->type = type;
  ast->value = left;
  ast->left = nullptr;
  ast->right = nullptr;

  return ast;
}

// Make an AST with the given subtree, type, and value, having no right subtree
AST * makeSingleWithValue(int type, int value, AST * ast)
{
  AST * stmt = makeASTWithValue(type, value, ast, nullptr);

  return stmt;
}

// Make an AST with the given type and subtrees
AST * makeAST(int type, AST * left, AST * right)
{
  AST * ast = (AST *)malloc(sizeof(AST));
  ast->type = type;
  ast->left = left;
  ast->right = right;

  return ast;
}

// Make an AST with the given type, value, and subtrees
AST * makeASTWithValue(int type, int value, AST * left, AST * right)
{
  AST * ast = (AST *)malloc(sizeof(AST));
  ast->type = type;
  ast->value = value;
  ast->left = left;
  ast->right = right;

  return ast;
}

// Add a statement AST to a statement list AST
void appendAST(AST * list, AST * stmt)
{
  AST * tail = list;
  while(tail->right != nullptr)
  {
    tail = tail->right;
  }

  tail->right = stmt;
}

// Recursively walk the AST, immediately executing each node
int eval(AST * ast)
{
  int result = 0; // The result of an expression

  if (ast != nullptr)
  {
    /* printf("Current: %c, Value: %d Left: %c, Right: %c\n", ast->type, ast->value, left, right); */
    switch (ast->type)
    {
      // Primary value-holders
      case NUM: result = ast->value;
      break;
      case VAR: result = getValue(ast->value)[1];
      break;

      // Expressions
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

      // Statements
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

// Get the register associated with the given symbol
int registerNumber(char symbol)
{
  for (size_t i = 0; i < symbols.size(); ++i)
  {
    if (symbols[i].name == symbol)
    {
      return i + 2;
    }
  }

  return 0;
}

// Reserve a temporary register
int getTemporary()
{
  if (symbols.size() < NUM_OF_REGISTERS)
  {
    symbols.push_back(Symbol());
  }

  return symbols.size() + 2;
}

// Insert a value that is sizeOfValue long into the instruction
void addToInstruction(long & instruction, int value, int sizeOfValue)
{
  instruction = instruction << sizeOfValue;
  instruction = instruction | value;
}

// Create an instruction that does a addition, subtraction, multiplication, or comparison
Operand createExpressionInstruction(AST * ast, int immediateOpcode, int immediateLayout, int registerOpcode, int registerLayout)
{
  Operand operand;      // The result of the expression
  Operand left;         // The result of the left operand of the expression
  Operand right;        // The result of the right operand of the expression
  long instruction = 0; // The instruction executing the expression

  // Set the result register
  operand.type = REGISTER;
  operand.value = getTemporary();

  // Compile the sub-expressions
  left = compile(ast->left);
  right = compile(ast->right);

  // If the left operand is an immediate, store it in a temporary register
  if (left.type == IMMEDIATE)
  {
    addToInstruction(instruction, left.value, 0);
    left.value = getTemporary();
    addToInstruction(instruction, left.value, 8);
    addToInstruction(instruction, 0, 8);
    addToInstruction(instruction, 0x3, 8);
    program.push_back(instruction);
    instruction = 0;
  }

  // operand = right OP left
  addToInstruction(instruction, right.value, 0);
  addToInstruction(instruction, left.value, 8);
  addToInstruction(instruction, operand.value, 8);

  // Use the correct kind of instruction depending on type
  if (right.type == IMMEDIATE)
  {
    addToInstruction(instruction, immediateOpcode, 8);
    addToInstruction(instruction, immediateLayout, 8);
  }
  else
  {
    addToInstruction(instruction, registerOpcode, 8);
    addToInstruction(instruction, registerLayout, 8);
  }

  program.push_back(instruction);

  return operand;
}

// Recursively walk the AST, creating and emitting instructions along the way
Operand compile(AST * ast)
{
  Operand operand;        // The result of this node's instruction
  Operand left;           // The result of the left subtree's compilation
  Operand right;          // The result of the right subtree's compilation
  long instruction = 0;   // The instruction to be built by this function
  size_t startTarget = 0; // The address of the beginning of a loop
  size_t endTarget = 0;   // The address of the end of a loop
  size_t skipTarget = 0;  // The address of a jump to skip a block of code

  if (ast != nullptr)
  {
    /* printf("Current: %c, Value: %d Left: %c, Right: %c\n", ast->type, ast->value, left, right); */
    switch (ast->type)
    {
      // Primary value-holders
      case NUM:
        operand.type = IMMEDIATE;
        operand.value = ast->value;
      break;
      case VAR:
        operand.type = REGISTER;
        operand.value = registerNumber(ast->value);
      break;

      // Expressions
      case GREATER_THAN: operand = createExpressionInstruction(ast, 0xC, 0x4, 0x1, 0x2);
      break;
      case LESS_THAN: operand = createExpressionInstruction(ast, 0xB, 0x4, 0x0, 0x2);
      break;
      case PLUS: operand = createExpressionInstruction(ast, 0x2, 0x4, 0x2, 0x5);
      break;
      case MINUS: operand = createExpressionInstruction(ast, 0x3, 0x4, 0x3, 0x5);
      break;
      case MULT: operand = createExpressionInstruction(ast, 0x4, 0x4, 0x0, 0x5);
      break;
      case DIV:
        operand.type = REGISTER;
        operand.value = getTemporary();
        left = compile(ast->left);
        right = compile(ast->right);

        // If the left operand is an immediate, store it in a temporary register
        if (left.type == IMMEDIATE)
        {
          addToInstruction(instruction, left.value, 0);
          left.value = getTemporary();
          addToInstruction(instruction, left.value, 8);
          addToInstruction(instruction, 0, 8);
          addToInstruction(instruction, 0x3, 8);
          program.push_back(instruction);
          instruction = 0;
        }

        // Build instruction
        addToInstruction(instruction, right.value, 0);
        addToInstruction(instruction, left.value, 8);

        left.value = getTemporary();
        addToInstruction(instruction, left.value, 8);
        addToInstruction(instruction, operand.value, 8);

        if (right.type == IMMEDIATE)
        {
          addToInstruction(instruction, 0x5, 8);
          addToInstruction(instruction, 0x4, 8);
        }
        else
        {
          addToInstruction(instruction, 0, 8);
          addToInstruction(instruction, 0x5, 8);
        }

        program.push_back(instruction);
      break;

      // Statements
      case ASSIGN:
        // Compile the expression to assign
        left = compile(ast->left);

        // Build an instruction either for immediate or register assignment
        if (left.type == IMMEDIATE)
        {
          addToInstruction(instruction, left.value, 0);
          addToInstruction(instruction, registerNumber(ast->value), 8);
          addToInstruction(instruction, 0, 8);
          addToInstruction(instruction, 0x3, 8);
        }
        else if (left.type == REGISTER)
        {
          addToInstruction(instruction, registerNumber(ast->value), 0);
          addToInstruction(instruction, 0, 16);
          addToInstruction(instruction, left.value, 8);
          addToInstruction(instruction, 0x7, 8);
          addToInstruction(instruction, 0x5, 8);
        }

        program.push_back(instruction);
      break;
      case PROCEDURE:
        // Get the register to print from
        left = compile(ast->left);

        // Build a print instruction
        addToInstruction(instruction, left.value, 0);
        addToInstruction(instruction, 0, 8);
        addToInstruction(instruction, 0x1, 8);
        program.push_back(instruction);
      break;
      case CONDITION:
        // Compile the condition
        left = compile(ast->left);

        // Store the result register in the right subtree and compile it
        ast->right->value = left.value;
        compile(ast->right);
      break;
      case IF_ELSE:
        // Skip next instruction if condition is true
        addToInstruction(instruction, 0x1, 0);
        addToInstruction(instruction, 0x1, 8);
        addToInstruction(instruction, ast->value, 8);
        addToInstruction(instruction, 0xE, 8);
        addToInstruction(instruction, 0x4, 8);
        program.push_back(instruction);
        instruction = 0;

        // Placehoder for the jump past the if statement
        program.push_back(0);
        skipTarget = program.size() - 1;

        // Compile the if statement's body
        left = compile(ast->left);

        // Create and insert the jump past the if statement
        endTarget = program.size() - 1;
        addToInstruction(instruction, endTarget, 0);
        addToInstruction(instruction, 0, 8);
        addToInstruction(instruction, 0x1, 8);
        addToInstruction(instruction, 0x3, 8);
        program[skipTarget] = instruction;
        instruction = 0;
      break;
      case WHILE:
        // Mark the top of the loop
        startTarget = program.size() - 1;

        // Compile the comparison
        left = compile(ast->left);

        // Skip the next line if condition is true
        addToInstruction(instruction, 0x1, 0);
        addToInstruction(instruction, 0x1, 8);
        addToInstruction(instruction, left.value, 8);
        addToInstruction(instruction, 0xE, 8);
        addToInstruction(instruction, 0x4, 8);
        program.push_back(instruction);
        instruction = 0;

        // Mark where to insert the jump past the while loop
        program.push_back(0);
        skipTarget = program.size() - 1;

        // Compile the loop body
        right = compile(ast->right);

        // Jump back to the beginning at the botton of the loop body
        addToInstruction(instruction, startTarget, 0);
        addToInstruction(instruction, 0, 8);
        addToInstruction(instruction, 0x1, 8);
        addToInstruction(instruction, 0x3, 8);
        program.push_back(instruction);
        instruction = 0;

        // Create and insert the jump over the while loop
        endTarget = program.size() - 1;
        addToInstruction(instruction, endTarget, 0);
        addToInstruction(instruction, 0, 8);
        addToInstruction(instruction, 0x1, 8);
        addToInstruction(instruction, 0x3, 8);
        program[skipTarget] = instruction;
        instruction = 0;
      break;
      case LIST:
        // Compile the statement in left, and the list contained in right
        compile(ast->left);
        compile(ast->right);
      break;
    }
  }

  return operand;
}

int main()
{
	pascalparse();
	return 0;
}

int yyerror(const char * s)
{
	fprintf(stderr, "Parse error: %s\n", s);
  return -1;
}
