# UWP price-string format inventory (FP-43192)

Parsed from a one-off prod `main2.tradeLog` export of all distinct `Price found` strings for products
#2230 ($9.99) and #2190 ($99.99) across all users (the raw export was not retained — reproducible from
`tradeLog` within its 90-day window). Sections below: all separator chars seen, decimal-separator
breakdown, the full format-signature list (digits as `D`), and the formats whose decimal separator is
NOT ASCII `.`/`,` (the broken set). Generated 2026-06-02.

entries=665 matched=665 total_events=708096

=== ALL SEPARATOR CHARS ===
  U+002E DOT          events=   393141  ex: 99.99 USD -> 99.99
  U+002C COMMA        events=   369972  ex: 99,99 EUR -> 99,99
  U+00A0 NBSP         events=    25184  ex: 2 560,00 UAH -> 2560
  U+066B ARABIC-DEC   events=     1610  ex: 37٫50 SAR -> 3750
  U+066C ARABIC-THOU  events=      445  ex: 111٬000٫000 IQD -> 111000000
  U+0024 '$'          events=      152  ex: 99$99 USD -> 9999
  U+202F NNBSP        events=       97  ex: 10 799,00 DZD -> 10799
  U+002D HYPHEN       events=        6  ex: 349-95 BRL -> 34995
  U+0027 "'"          events=        2  ex: 1'679,00 ZAR -> 1679

=== DECIMAL SEPARATOR (rightmost) ===
  U+002E DOT          events=   359248  ex: 99.99 USD -> 99.99
  U+002C COMMA        events=   346891  ex: 99,99 EUR -> 99,99
  U+066B ARABIC-DEC   events=     1610  ex: 37٫50 SAR -> 3750  <<< BREAKS PARSER
  U+0024 '$'          events=      152  ex: 99$99 USD -> 9999  <<< BREAKS PARSER
  U+00A0 NBSP         events=      144  ex: 1 299 RSD -> 1299  <<< BREAKS PARSER
  U+066C ARABIC-THOU  events=       18  ex: 111٬000 IQD -> 111000  <<< BREAKS PARSER
  U+002D HYPHEN       events=        6  ex: 349-95 BRL -> 34995  <<< BREAKS PARSER

=== FORMAT SIGNATURES (all) ===
  DD.DD            events=   157330  ex: 99.99 USD -> 99.99
  DD,DD            events=   131965  ex: 99,99 EUR -> 99,99
  D.DD             events=   123975  ex: 9.99 USD -> 9.99
  D,DD             events=    79977  ex: 9,99 EUR -> 9,99
  DDD,DD           events=    73286  ex: 459,99 PLN -> 459,99
  DDD.DD           events=    50229  ex: 149.95 AUD -> 149.95
  D DDD,DD         events=    21657  ex: 2 560,00 UAH -> 2560
  D,DDD.DD         events=    18173  ex: 1,900.00 TRY -> 1900
  DDD.DDD,DD       events=     9622  ex: 130.000,00 IDR -> 130000
  D.DDD,DD         events=     8807  ex: 5.399,00 ARS -> 5399
  D.DDD.DDD,DD     events=     8794  ex: 1.310.000,00 IDR -> 1310000
  DD.DDD,DD        events=     6670  ex: 53.999,00 ARS -> 53999
  DD DDD,DD        events=     3361  ex: 34 900,00 HUF -> 34900
  DDD,DDD.DD       events=     1764  ex: 130,000.00 IDR -> 130000
  DD.DDD           events=     1737  ex: 67.999 CLP -> 67999
  D.DDD            events=     1727  ex: 6.799 CLP -> 6799
  D,DDD,DDD.DD     events=     1723  ex: 1,310,000.00 IDR -> 1310000
  DD,DDD.DD        events=     1351  ex: 53,999.00 ARS -> 53999
  DDD,DDD          events=      827  ex: 219,900 VND -> 219900
  DD,DDD           events=      702  ex: 12,899 RSD -> 12899
  D,DDD,DDD        events=      610  ex: 2,219,900 VND -> 2219900
  DDD.DDD          events=      534  ex: 219.900 VND -> 219900
  DDD٫DD           events=      525  ex: 374٫00 SAR -> 37400
  D.DDD.DDD        events=      523  ex: 2.219.900 VND -> 2219900
  D,DDD            events=      511  ex: 1,299 RSD -> 1299
  DD٫DD            events=      480  ex: 37٫50 SAR -> 3750
  DDD٬DDD٫DDD      events=      160  ex: 111٬000٫000 IQD -> 111000000
  DD٬DDD٫DDD       events=      160  ex: 11٬000٫000 IQD -> 11000000
  D٬DDD٫DD         events=      107  ex: 1٬900٫00 TRY -> 190000
  DD$DD            events=       76  ex: 99$99 USD -> 9999
  D$DD             events=       74  ex: 9$99 USD -> 999
  D DDD            events=       69  ex: 1 299 RSD -> 1299
  DD DDD           events=       69  ex: 12 899 RSD -> 12899
  D٫DD             events=       62  ex: 9٫99 USD -> 999
  D٫DDD            events=       58  ex: 9٫500 JOD -> 9500
  DD٫DDD           events=       58  ex: 95٫500 JOD -> 95500
  D DDD,DD         events=       57  ex: 1 099,00 DZD -> 1099
  D.DDD.DDD.DD     events=       47  ex: 1.310.000.00 IDR -> 0
  DDD.DDD.DD       events=       47  ex: 130.000.00 IDR -> 0
  DD DDD,DD        events=       40  ex: 10 799,00 DZD -> 10799
  DD,DDD.DDD       events=       31  ex: 11,000.000 IQD -> 11000
  DDD,DDD.DDD      events=       31  ex: 111,000.000 IQD -> 111000
  DDD              events=       27  ex: 939 ISK -> 939
  D DDD.DD         events=       20  ex: 1 679.00 ZAR -> 1679
  DDD٬DDD          events=        9  ex: 111٬000 IQD -> 111000
  DD٬DDD           events=        9  ex: 11٬000 IQD -> 11000
  DDD-DD           events=        3  ex: 349-95 BRL -> 34995
  DD-DD            events=        3  ex: 34-95 BRL -> 3495
  D,DD,DDD.DD      events=        3  ex: 1,30,000.00 IDR -> 130000
  DD,DD,DDD.DD     events=        3  ex: 13,10,000.00 IDR -> 1310000
  DDD$DD           events=        2  ex: 349$95 BRL -> 34995
  D,DDD DD         events=        2  ex: 1,679 00 ZAR -> 1.679
  D'DDD,DD         events=        2  ex: 1'679,00 ZAR -> 1679
  DDD DD           events=        2  ex: 169 00 ZAR -> 16900
  DDD DDD          events=        1  ex: 219 900 VND -> 219900
  D DDD DDD        events=        1  ex: 2 219 900 VND -> 2219900
  DDDD,DD          events=        1  ex: 2560,00 UAH -> 2560
  DDD DDD,DD       events=        1  ex: 130 000,00 IDR -> 130000
  D DDD DDD,DD     events=        1  ex: 1 310 000,00 IDR -> 1310000

=== ENTRIES WHOSE DECIMAL SEP IS NOT . OR , (broken) ===
  events=     399  '37٫50' SAR -> 3750
  events=     399  '374٫00' SAR -> 37400
  events=     160  '111٬000٫000' IQD -> 111000000
  events=     160  '11٬000٫000' IQD -> 11000000
  events=      74  '99$99' USD -> 9999
  events=      74  '9$99' USD -> 999
  events=      69  '1\xa0299' RSD -> 1299
  events=      69  '12\xa0899' RSD -> 12899
  events=      69  '190٫00' TRY -> 19000
  events=      69  '1٬900٫00' TRY -> 190000
  events=      52  '99٫99' USD -> 9999
  events=      52  '9٫99' USD -> 999
  events=      47  '9٫500' JOD -> 9500
  events=      47  '95٫500' JOD -> 95500
  events=      37  '3٬045٫00' EGP -> 304500
  events=      37  '305٫00' EGP -> 30500
  events=      19  '375٫00' ILS -> 37500
  events=      19  '37٫50' ILS -> 3750
  events=       9  '111٬000' IQD -> 111000
  events=       9  '11٬000' IQD -> 11000
  events=       6  '83٫49' GBP -> 8349
  events=       6  '8٫39' GBP -> 839
  events=       6  '30٫000' KWD -> 30000
  events=       6  '3٫000' KWD -> 3000
  events=       4  '9٫99' EUR -> 999
  events=       4  '99٫99' EUR -> 9999
  events=       3  '349-95' BRL -> 34995
  events=       3  '34-95' BRL -> 3495
  events=       3  '38٫000' BHD -> 38000
  events=       3  '3٫800' BHD -> 3800
  events=       2  '3٫900' OMR -> 3900
  events=       2  '39٫000' OMR -> 39000
  events=       2  '349$95' BRL -> 34995
  events=       2  '1,679\xa000' ZAR -> 1.679
  events=       2  '169\xa000' ZAR -> 16900
  events=       2  '34$95' BRL -> 3495
  events=       1  '145٫00' MXN -> 14500
  events=       1  '219\xa0900' VND -> 219900
  events=       1  '2\xa0219\xa0900' VND -> 2219900
  events=       1  '1٬439٫00' MXN -> 143900

  >>> total broken events: 1930, distinct broken formats: 40