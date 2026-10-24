// Shown instantly on navigation while the server reads the page's data. The
// blocks match the real header, stat row and table heights, so nothing jumps
// when content streams in.
export default function Loading() {
  return (
    <div aria-busy="true" aria-label="Loading">
      <div className="page-head">
        <div>
          <span className="sk sk-eyebrow" />
          <span className="sk sk-title" />
        </div>
      </div>
      <div className="stack-lg">
        <div className="stat-grid">
          {[0, 1, 2, 3].map((key) => <span key={key} className="sk sk-stat" />)}
        </div>
        <div className="card">
          <div className="card-head"><span className="sk sk-line w-40" /></div>
          {[0, 1, 2, 3, 4, 5].map((key) => (
            <div key={key} className="list-item">
              <span className="sk sk-line w-60" />
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
