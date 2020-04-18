int main() {
    int a = 12;
    int b = 4279;
    int c = 0;
    for(int i = 0; i < 10000; i++) {
        if(i & 0x1) {
            a = b + 15;
            c = a - 4;
            b++;
        }
        else {
            a = c + 1;
            b = a;
            c = b - c;
        }
        a = a * c;
        if(i & 0x7 == 0) {
            a++;
            c = c + a;
        }
        else if(i & 0x3 == 0) {
            b = 200 + a;
        }
        switch(i & 0x3) {
            case 0:
                a = 27 + b + 2 * c;
                b = 800;
                break;
            case 1:
                c = 500 + 3 * a - b;
                break;
            case 2:
                a = 500;
                c = 50 + a + 3 * b;
            case 3:
                b = a * 2 - c * 3;
                break;
            default:
                a = 10 * b * c;
                break;
        }
    }
}
