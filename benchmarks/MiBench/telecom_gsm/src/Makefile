# Declarations
COMPILER = moxie-elf-gcc -Tsim.ld
OPTS_DEF = -O2
MISC_OPTS = -lm -DSASR -DSTUPID_COMPILER -DNeedFunctionPrototypes=1

# Actions
all:		
	$(COMPILER) *.c $(OPTS_DEF) $(MISC_OPTS) 
