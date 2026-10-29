/* Stand-in for Claude Desktop in tests: logs its arguments and
 * CLAUDE_CONFIG_DIR to <sandbox>/launches/<pid>.log, then idles. */
#include <libgen.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
  char dir[PATH_MAX], path[PATH_MAX];
  strncpy(dir, argv[0], sizeof dir - 1);
  dir[sizeof dir - 1] = '\0';
  snprintf(path, sizeof path, "%s/../../../../launches/%d.log", dirname(dir), (int)getpid());
  FILE *f = fopen(path, "w");
  if (!f) return 1;
  fputs("args=", f);
  for (int i = 1; i < argc; i++) fprintf(f, "%s%s", i > 1 ? " " : "", argv[i]);
  const char *cfg = getenv("CLAUDE_CONFIG_DIR");
  fprintf(f, "\ncfg=%s\n", cfg ? cfg : "<unset>");
  fclose(f);
  for (;;) sleep(1);
}
