export function acceptsNoArguments(
  command: string,
  arguments_: readonly string[],
  printCommandHelp_: () => void,
): boolean {
  if (arguments_.length === 0) {
    return true;
  }

  console.error(`Unexpected ${command} option: ${arguments_[0]}`);
  printCommandHelp_();
  return false;
}

export function isHelpRequest(arguments_: readonly string[]): boolean {
  return (
    arguments_.length === 1 &&
    (arguments_[0] === '--help' || arguments_[0] === '-h')
  );
}
