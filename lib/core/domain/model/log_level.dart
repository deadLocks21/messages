/// Sévérité d'un enregistrement de log.
///
/// Calquée sur l'échelle OpenTelemetry `SeverityNumber`, pour que les
/// adaptateurs d'infra n'aient pas à inventer leur propre traduction.
enum LogLevel {
  debug(5, 'DEBUG'),
  info(9, 'INFO'),
  warn(13, 'WARN'),
  error(17, 'ERROR');

  const LogLevel(this.otelSeverityNumber, this.otelSeverityText);

  final int otelSeverityNumber;
  final String otelSeverityText;
}
