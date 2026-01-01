// Initialize Mermaid
document$.subscribe(function() {
  mermaid.initialize({
    startOnLoad: true,
    theme: 'default',
    themeVariables: {
      primaryColor: '#e8f4f8',
      primaryTextColor: '#000',
      primaryBorderColor: '#7C0000',
      lineColor: '#999',
      secondaryColor: '#fff4e6',
      tertiaryColor: '#f0f0f0'
    }
  });
  mermaid.contentLoaded();
});
