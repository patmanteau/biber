package Biber::Date::Format;
use v5.16;

use strict;
use Carp;
use Data::Dump;
use parent qw(DateTime::Format::ISO8601);

=encoding utf-8

=head1 NAME

Biber::Date::Format

=head2 Description

  Subclass of DateTime::Format::ISO8601 which allows detection of missing month/year and
  with time parsers removed as they are not needed.
  Also added a ->missing() method to detect when month/year are missing.

=cut

# sub new {
#   my $class = shift;
#   my $self = $class->SUPER::new();
#   # Initialise missing tracker
#   $self->{missing} = {};
#   return $self;
# }

sub missing {
  my $self = shift;
  my $part = shift;
  return $self->{missing}{$part};
}

DateTime::Format::Builder->create_class(
    parsers => {
        parse_datetime => [
            [ preprocess => \&_reset_missing ],
            {
                #YYYYMMDD 19850412
                length => 8,
                regex  => qr/^ (\d{4}) (\d\d) (\d\d) $/x,
                params => [ qw( year month day ) ],
            },
            {
                # uncombined with above because 
                #regex => qr/^ (\d{4}) -??  (\d\d) -?? (\d\d) $/x,
                # was matching 152746-05

                #YYYY-MM-DD 1985-04-12
                length => 10,
                regex  => qr/^ (\d{4}) - (\d\d) - (\d\d) $/x,
                params => [ qw( year month day ) ],
            },
            {
                #YYYY-MM 1985-04
                length => 7,
                regex  => qr/^ (\d{4}) - (\d\d) $/x,
                params => [ qw( year month ) ],
                postprocess => \&_missing_day,
            },
            {
                #YYYY 1985
                length => 4,
                regex  => qr/^ (\d{4}) $/x,
                params => [ qw( year ) ],
                postprocess => [ \&_missing_month, \&_missing_day ],
            },
            {
                #YY 19 (century)
                length => 2,
                regex  => qr/^ (\d\d) $/x,
                params => [ qw( year ) ],
                postprocess => [ \&_normalize_century, \&_missing_month, \&_missing_day ],
            },
            {
                #YYMMDD 850412
                #YY-MM-DD 85-04-12
                length => [ qw( 6 8 ) ],
                regex  => qr/^ (\d\d) -??  (\d\d) -?? (\d\d) $/x,
                params => [ qw( year month day ) ],
                postprocess => \&_fix_2_digit_year,
            },
            {
                #-YYMM -8504
                #-YY-MM -85-04
                length => [ qw( 5 6 ) ],
                regex  => qr/^ - (\d\d) -??  (\d\d) $/x,
                params => [ qw( year month ) ],
                postprocess => [ \&_fix_2_digit_year, \&_missing_month ],
            },
            {
                #-YY -85
                length   => 3,
                regex    => qr/^ - (\d\d) $/x,
                params   => [ qw( year ) ],
                postprocess => [ \&_fix_2_digit_year, \&_missing_month, \&_missing_day ],
            },
            {
                #--MMDD --0412
                #--MM-DD --04-12
                length => [ qw( 6 7 ) ],
                regex  => qr/^ -- (\d\d) -??  (\d\d) $/x,
                params => [ qw( month day ) ],
                postprocess => [ \&_add_year, \&_missing_year ],
            },
            {
                #--MM --04
                length => 4,
                regex  => qr/^ -- (\d\d) $/x,
                params => [ qw( month ) ],
                postprocess => [ \&_add_year, \&_missing_year, \&_missing_day ],
            },
            {
                #---DD ---12
                length => 5,
                regex  => qr/^ --- (\d\d) $/x,
                params => [ qw( day ) ],
                postprocess => [ \&_add_year, \&_add_month, \&_missing_year, \&_missing_month ],
            },
            {
                #+[YY]YYYYMMDD +0019850412
                #+[YY]YYYY-MM-DD +001985-04-12
                length => [ qw( 11 13 ) ],
                regex  => qr/^ \+ (\d{6}) -?? (\d\d) -?? (\d\d)  $/x,
                params => [ qw( year month day ) ],
            },
            {
                #+[YY]YYYY-MM +001985-04
                length => 10,
                regex  => qr/^ \+ (\d{6}) - (\d\d)  $/x,
                params => [ qw( year month ) ],
            },
            {
                #+[YY]YYYY +001985
                length => 7,
                regex  => qr/^ \+ (\d{6}) $/x,
                params => [ qw( year ) ],
            },
            {
                #+[YY]YY +0019 (century)
                length => 5,
                regex  => qr/^ \+ (\d{4}) $/x,
                params => [ qw( year ) ],
                postprocess => \&_normalize_century,
            },
            {
                #YYYYDDD 1985102
                #YYYY-DDD 1985-102
                length => [ qw( 7 8 ) ],
                regex  => qr/^ (\d{4}) -?? (\d{3}) $/x,
                params => [ qw( year day_of_year ) ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #YYDDD 85102
                #YY-DDD 85-102
                length => [ qw( 5 6 ) ],
                regex  => qr/^ (\d\d) -?? (\d{3}) $/x,
                params => [ qw( year day_of_year ) ],
                postprocess => [ \&_fix_2_digit_year ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #-DDD -102
                length => 4,
                regex  => qr/^ - (\d{3}) $/x,
                params => [ qw( day_of_year ) ],
                postprocess => [ \&_add_year ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #+[YY]YYYYDDD +001985102
                #+[YY]YYYY-DDD +001985-102
                length => [ qw( 10 11 ) ],
                regex  => qr/^ \+ (\d{6}) -?? (\d{3}) $/x,
                params => [ qw( year day_of_year ) ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #YYYYWwwD 1985W155
                #YYYY-Www-D 1985-W15-5
                length => [ qw( 8 10 ) ],
                regex  => qr/^ (\d{4}) -?? W (\d\d) -?? (\d) $/x,
                params => [ qw( year week day_of_year ) ],
                postprocess => [ \&_normalize_week ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #YYYYWww 1985W15
                #YYYY-Www 1985-W15
                length => [ qw( 7 8 ) ],
                regex  => qr/^ (\d{4}) -?? W (\d\d) $/x,
                params => [ qw( year week ) ],
                postprocess => [ \&_normalize_week ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #YYWwwD 85W155
                #YY-Www-D 85-W15-5
                length => [ qw( 6 8 ) ],
                regex  => qr/^ (\d\d) -?? W (\d\d) -?? (\d) $/x,
                params => [ qw( year week day_of_year ) ],
                postprocess => [ \&_fix_2_digit_year, \&_normalize_week ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #YYWww 85W15
                #YY-Www 85-W15
                length => [ qw( 5 6 ) ],
                regex  => qr/^ (\d\d) -?? W (\d\d) $/x,
                params => [ qw( year week ) ],
                postprocess => [ \&_fix_2_digit_year, \&_normalize_week ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #-YWwwD -5W155
                #-Y-Www-D -5-W15-5
                length => [ qw( 6 8 ) ],
                regex  => qr/^ - (\d) -?? W (\d\d) -?? (\d) $/x,
                params => [ qw( year week day_of_year ) ],
                postprocess => [ \&_fix_1_digit_year, \&_normalize_week ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #-YWww -5W15
                #-Y-Www -5-W15
                length => [ qw( 5 6 ) ],
                regex  => qr/^ - (\d) -?? W (\d\d) $/x,
                params => [ qw( year week ) ],
                postprocess => [ \&_fix_1_digit_year, \&_normalize_week ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #-WwwD -W155
                #-Www-D -W15-5
                length => [ qw( 5 6 ) ],
                regex  => qr/^ - W (\d\d) -?? (\d) $/x,
                params => [ qw( week day_of_year ) ],
                postprocess => [ \&_add_year, \&_normalize_week ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #-Www -W15
                length => 4,
                regex  => qr/^ - W (\d\d) $/x,
                params => [ qw( week ) ],
                postprocess => [ \&_add_year, \&_normalize_week ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #-W-D -W-5
                length => 4,
                regex  => qr/^ - W - (\d) $/x,
                params => [ qw( day_of_year ) ],
                postprocess => [
                    \&_add_year,
                    \&_add_week,
                    \&_normalize_week,
                ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #+[YY]YYYYWwwD +001985W155
                #+[YY]YYYY-Www-D +001985-W15-5
                length => [ qw( 11 13 ) ],
                regex  => qr/^ \+ (\d{6}) -?? W (\d\d) -?? (\d) $/x,
                params => [ qw( year week day_of_year ) ],
                postprocess => [ \&_normalize_week ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
            {
                #+[YY]YYYYWww +001985W15
                #+[YY]YYYY-Www +001985-W15
                length => [ qw( 10 11 ) ],
                regex  => qr/^ \+ (\d{6}) -?? W (\d\d) $/x,
                params => [ qw( year week ) ],
                postprocess => [ \&_normalize_week ],
                constructor => [ 'DateTime', 'from_day_of_year' ],
            },
        ],
    }
);

sub _reset_missing {
  my %args = @_;
  my ($date, $self) = @args{qw( input self )};
  delete $self->{missing};
  return $date;
}

sub _missing_year {
  my %p = @_;
  $p{self}{missing}{year} = 1;
  return 1;
}

sub _missing_month {
  my %p = @_;
  $p{self}{missing}{month} = 1;
  return 1;
}

sub _missing_day {
  my %p = @_;
  $p{self}{missing}{day} = 1;
  return 1;
}



1;