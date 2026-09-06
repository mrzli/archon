import { homedir } from 'node:os';
import { join } from 'node:path';

import type { EditorSessionDefinition, GroupContext, Tmux, WorkspaceAction } from '../shared/index.ts';
import { manageEditorSessions } from '../shared/index.ts';

const PROJECTS: readonly string[] = [
  'mrzli/archon',
  'mrzli/docs',
  'mrzli/js-templates',
  'mrzli/learning',
  'mrzli/repos',
];

export function manageMiscProjects(
  action: WorkspaceAction,
  context: GroupContext<Pick<Tmux, 'hasSession' | 'createEditorSession' | 'stopSession'>>,
): number {
  const homeDir = context.homeDir ?? homedir();
  const root = join(homeDir, 'projects/personal');
  const sessions: readonly EditorSessionDefinition[] = PROJECTS.map((project): EditorSessionDefinition => ({
    session: `project-${project.replaceAll('/', '-')}`,
    directory: join(root, project),
  }));

  return manageEditorSessions(action, sessions, context);
}
