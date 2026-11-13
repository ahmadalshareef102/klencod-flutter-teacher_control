/// رقم يوم الدراسة (0 = السبت ... 4 = الأربعاء)، أو null للخميس والجمعة.
int? studyDayIndex(DateTime date) {
  switch (date.weekday) {
    case DateTime.saturday:
      return 0;
    case DateTime.sunday:
      return 1;
    case DateTime.monday:
      return 2;
    case DateTime.tuesday:
      return 3;
    case DateTime.wednesday:
      return 4;
    default:
      return null;
  }
}
