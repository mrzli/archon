export function getErrorMessage(error) {
  return error instanceof Error ? error.message : String(error);
}

export function toSingleLine(value) {
  return String(value).replaceAll(/\s+/g, ' ').trim();
}
