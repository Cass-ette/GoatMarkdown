const vscode = require("vscode");
const { exec } = require("child_process");

function openInGoatMarkdown(path) {
  const encoded = encodeURIComponent(path);
  const url = `goatmarkdown://open?path=${encoded}`;
  const command = process.platform === "darwin" ? `open "${url}"` : `xdg-open "${url}"`;

  exec(command, (error) => {
    if (error) {
      vscode.window.showErrorMessage(`Failed to open GoatMarkdown: ${error.message}`);
    }
  });
}

function activate(context) {
  context.subscriptions.push(
    vscode.commands.registerCommand("goatmarkdown.openFile", (uri) => {
      if (uri && uri.fsPath) {
        openInGoatMarkdown(uri.fsPath);
      }
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand("goatmarkdown.openFolder", (uri) => {
      if (uri && uri.fsPath) {
        openInGoatMarkdown(uri.fsPath);
      }
    })
  );
}

function deactivate() {}

module.exports = { activate, deactivate };
