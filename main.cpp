///////////////////////////////////////////////////////////////////////////
/*
MIT License

Copyright (c) 2024 Antonio Sánchez (@TheSonders)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

 Antonio Sánchez (@TheSonders)
 References:
 -AMSTRAD CPC464 WHOLE MEMORY GUIDE (Don Thomasson) Chapter 13
    (From the Spanish Edition by Rafael Sarmiento de Sotomayor)
-https://en.wikipedia.org/wiki/Microsoft_Binary_Format

CONVERTER MBF40bits (aka 9-digit BASIC) to Float and vice versa
*/
///////////////////////////////////////////////////////////////////////////
#include <stdio.h>
#include <math.h>

double const POWER = pow(2.0, 32.0);
double MBF40ToDouble(long long int);
long long int DoubleToMBF40(double);

int main(void)
{
    long long int MBFin = 0;
    double dblIn = 0.0;

    long long int MBFout = 0;
    double dblOut = 0.0;
    while (1)
    {
        fflush(stdin);
        printf("\n-------------------------------------");
        printf("\n\t(Introduzca 0 para MBF->Coma flotante)");
        printf("\nIntroduzca el número en coma flotante: ");
        scanf("%lf", &dblIn, stdin);
        if (dblIn == 0)
        {

            printf("\n\nIntroduzca los 5 bytes MBF en formato hexadecimal: ");
            scanf("%lX", &MBFin, stdin);
            if (MBFin == 0)
                return 0;
            dblOut = MBF40ToDouble(MBFin);
            printf("\nResult:%lf", dblOut);
            MBFout = DoubleToMBF40(dblOut);
            printf("\nCheck:%lX(%lX)", MBFout, MBFin);
        }
        else
        {
            MBFout = DoubleToMBF40(dblIn);
            printf("\nResult:%lX", MBFout);
            dblOut = MBF40ToDouble(MBFout);
            printf("\nCheck:%lf(%lf)", dblOut, dblIn);
        }
    }
}

long long int DoubleToMBF40(double dblIn)
{
    int exponent = 32;
    int sign = 0;
    long long int mantissa = 0;
    long long int MBFout = 0;
    double value = 0.0;
    if (dblIn < 0)
    {
        dblIn = -dblIn;
        sign = 1;
    }
    value = dblIn;
    if (value < POWER)
    {
        while (exponent > -127)
        {
            dblIn = (value * 2);
            if (dblIn >= POWER)
                break;
            value = dblIn;
            exponent--;
        }
    }
    else
    {
        while (exponent < 128)
        {
            dblIn = (value / 2);
            value = dblIn;
            exponent++;
            if (dblIn < POWER)
                break;
        }
    }
    mantissa = abs((long long int)floor(value));
    MBFout = ((exponent + 0x80) & 0xFF);
    MBFout <<= 32;
    MBFout = MBFout | (mantissa & 0x7FFFFFFF);
    if (sign)
        MBFout = MBFout | 0x80000000;
    printf("\n\tValue:%lf", value);
    printf("\n\tExponent:%d", exponent);
    printf("\n\tSign:%d", sign);
    printf("\n\tMantissa:%u", mantissa);
    MBFout = MBFout & 0xFFFFFFFFFF;
    return MBFout;
}

double MBF40ToDouble(long long int nin)
{
    double value = 0.0;
    short int exponent = 0;
    short int sign = 0;
    long int mantissa = 0;
    exponent = (nin >> 32) & 0xFF;
    exponent -= 0x80;
    sign = (nin >> 31) & 0x01;
    mantissa = (nin & 0xFFFFFFFF) | (0x80000000);
    printf("\n\tMantissa:%lu(%lX)\n\tExponent:%d", mantissa, mantissa, exponent);
    printf("\n\tSign:%d", sign);
    value = abs((double)(mantissa) / POWER);
    if (sign)
        (value = -value);
    printf("\n\tValue:%lf", value);
    while (exponent != 0)
    {
        if (exponent > 0)
        {
            value = value * 2;
            exponent--;
        }
        else
        {
            value = value / 2;
            exponent++;
        }
    }
    return value;
}
