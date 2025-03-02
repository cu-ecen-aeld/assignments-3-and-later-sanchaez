CC=$(CROSS_COMPILE)gcc

writer: writer.o
	$(CC) $^ -o $@

writer.o: writer.c
	$(CC) -c $^ -o $@

.PHONY: clean
clean:
	rm -f writer.o
	rm -f writer