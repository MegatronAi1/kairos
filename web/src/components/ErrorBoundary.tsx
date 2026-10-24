import { Component, type ErrorInfo, type ReactNode } from "react";

import { ErrorState } from "@/components/primitives";

/** Keeps one broken panel from blanking the Control Room during a demo. */
export class ErrorBoundary extends Component<{ children: ReactNode; title?: string }, { error: Error | null }> {
  state = { error: null as Error | null };

  static getDerivedStateFromError(error: Error) {
    return { error };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error("panel crashed", error, info.componentStack);
  }

  render() {
    if (this.state.error)
      return (
        <ErrorState
          title={this.props.title ?? "This panel hit a problem"}
          message={this.state.error.message}
          onRetry={() => this.setState({ error: null })}
        />
      );
    return this.props.children;
  }
}
