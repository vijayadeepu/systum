enum FocusSessionStatus {
  running,
  paused,
  completed,
  interrupted,
  cancelled;

  bool get isTerminal =>
      this == completed || this == interrupted || this == cancelled;
}
