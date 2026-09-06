export function getErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

export function toSingleLine(value: unknown): string {
  return String(value).replaceAll(/\s+/g, ' ').trim();
}
