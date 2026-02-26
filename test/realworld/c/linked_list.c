// linked_list.c — malloc/free with linked list operations
#include <stdio.h>
#include <stdlib.h>

typedef struct Node {
    int value;
    struct Node *next;
} Node;

Node *push(Node *head, int val) {
    Node *n = (Node *)malloc(sizeof(Node));
    if (!n) return head;
    n->value = val;
    n->next = head;
    return n;
}

int sum_list(Node *head) {
    int s = 0;
    for (Node *cur = head; cur; cur = cur->next)
        s += cur->value;
    return s;
}

void free_list(Node *head) {
    while (head) {
        Node *tmp = head;
        head = head->next;
        free(tmp);
    }
}

int main(void) {
    Node *list = NULL;
    for (int i = 1; i <= 1000; i++)
        list = push(list, i);

    int total = sum_list(list);
    printf("linked list sum: %d\n", total); // 500500
    free_list(list);
    return 0;
}
