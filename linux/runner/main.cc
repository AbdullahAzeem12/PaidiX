// Starts the GTK Flutter runner and enters the desktop application event loop.
#include "my_application.h"

// Creates the GTK application and runs its event loop until it exits.
int main(int argc, char** argv) {
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
