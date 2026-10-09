import Foundation

/// Presentation only: no policy text, links or document nodes are replaced.
/// Limited to the two supplied Koko policy sites; other destinations stay intact.
enum KokoPolicyReadingStyle {
    static func script(enabled: Bool) -> String {
        let enabledLiteral = enabled ? "true" : "false"
        return """
        (() => {
          const styleID = 'koko-policy-reading-style';
          const previous = document.getElementById(styleID);
          if (!\(enabledLiteral)) { previous?.remove(); return; }
          const allowed = [
            '/view/koko-terms-of-service/about',
            '/view/koko-privacypolicy/about'
          ];
          if (location.hostname !== 'sites.google.com' ||
              !allowed.includes(location.pathname.replace(/\\/$/, ''))) return;
          if (!document.querySelector('section.yaqOZd .tyJCtd')) return;
          if (previous) return;
          const style = document.createElement('style');
          style.id = styleID;
          style.textContent = `
            html, body { background: #F6F9F3 !important; color: #132A26 !important; }
            #atIdViewHeader { display: none !important; }
            .UtePc { padding-top: 0 !important; }
            section.yaqOZd { background: #F6F9F3 !important; padding: 16px 24px !important; }
            section.yaqOZd > .IFuOkc { background: none !important; }
            section.yaqOZd .mYVXT, section.yaqOZd .LS81yb {
              max-width: 720px !important; margin: 0 auto !important; padding: 0 !important;
            }
            section[id^="h.INITIAL_GRID"] {
              min-height: 0 !important; height: auto !important; padding-top: 28px !important;
            }
            section[id^="h.INITIAL_GRID"] * {
              background-image: none !important; min-height: 0 !important; height: auto !important;
            }
            section[id^="h.INITIAL_GRID"] > .IFuOkc { display: none !important; }
            section[id^="h.INITIAL_GRID"] .LS81yb { display: block !important; }
            section[id^="h.INITIAL_GRID"] [class*="hJDwNd-"] {
              width: 100% !important; margin: 0 !important;
            }
            .tyJCtd { padding: 0 !important; }
            .tyJCtd p, .tyJCtd li {
              color: #243C34 !important; font-family: 'Avenir Next', sans-serif !important;
              font-size: 16px !important; line-height: 1.65 !important;
              margin-top: 0 !important; margin-bottom: 16px !important;
              overflow-wrap: anywhere;
            }
            .tyJCtd p span, .tyJCtd li span {
              font-family: inherit !important; font-size: inherit !important;
              line-height: inherit !important; color: inherit !important;
            }
            .tyJCtd h1, .tyJCtd h2, .tyJCtd h3 {
              font-family: 'Avenir Next', sans-serif !important;
              color: #132A26 !important; text-align: left !important;
              line-height: 1.3 !important; margin: 24px 0 12px !important;
            }
            .tyJCtd h1 { font-size: 28px !important; margin-top: 0 !important; }
            .tyJCtd h2 { font-size: 21px !important; }
            .tyJCtd h3 { font-size: 18px !important; }
            .tyJCtd h1 span, .tyJCtd h2 span, .tyJCtd h3 span {
              color: inherit !important; font-family: inherit !important;
              font-size: inherit !important; line-height: inherit !important;
            }
            .tyJCtd a, .tyJCtd a span {
              color: #28654E !important; text-decoration: underline !important;
            }
            .tyJCtd table { max-width: 100% !important; }
          `;
          document.head.appendChild(style);
        })();
        """
    }
}
