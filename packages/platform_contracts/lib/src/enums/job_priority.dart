/// Bounded scheduling priority. Ordering is deterministic: within all
/// runnable jobs an eligible queue is ordered by [order] descending, then
/// `availableAt`, then `createdAt`, then stable id. No AI or learned
/// prioritization exists.
enum JobPriority {
  low(10),
  normal(20),
  high(30),
  critical(40);

  const JobPriority(this.order);

  final int order;
}
