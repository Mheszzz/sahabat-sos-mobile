void main() {
  String d1 = "2024-05-12 10:00:00";
  String d2 = "2024-05-12T10:00:00.000000Z";
  String d3 = "2024-05-12T10:00:00+07:00";
  String d4 = "2024-05-12T10:00:00-05:00";
  
  List<String> dates = [d1, d2, d3, d4];
  for (String rawDate in dates) {
    String parseableDate = rawDate.replaceAll(' ', 'T');
    if (!parseableDate.endsWith('Z') && 
        !parseableDate.contains('+') && 
        (parseableDate.indexOf('T') == -1 || parseableDate.indexOf('-', parseableDate.indexOf('T')) == -1)) {
      parseableDate += 'Z';
    }
    DateTime parsed = DateTime.parse(parseableDate).toLocal();
    print("Orig: " + rawDate + " -> Parseable: " + parseableDate + " -> Local: " + parsed.toString());
  }
}
