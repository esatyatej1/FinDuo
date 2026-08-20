import 'lib/services/phonepe_parser.dart';

void main() {
  final title = "Money transfer successful";
  final content = "₹5 has been sent to 9000412363@axisbank";

  final result = PhonePeParser.parseTransaction(title, content);
  print(result);
}
