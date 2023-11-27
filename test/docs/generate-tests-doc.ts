import * as fs from "fs";

const parseFile = (filename: string): Promise<string> => {
  return new Promise((resolve, reject) => {
    fs.readFile(filename, "utf-8", (err, data) => {
      if (err) {
        console.error(`Error reading file ${filename}: ${err}`);
        return err;
      }

      let markdownContent = "";

      const lines = data.split("\n").map((line) => line.trim());
      for (const line of lines) {
        if (line.startsWith("describe('")) {
          const start = "describe('".length;
          const end = line.indexOf("',");

          const describe = line.substring(start, end);
          // console.log(`# ${describe}\n`);
          markdownContent += `# ${describe}\n`;
        } else if (line.startsWith("async function ")) {
          const start = "async function ".length;
          const end = line.indexOf("(");

          const functionName = line.substring(start, end);
          // console.log(`\n## ${functionName}\n`);
          markdownContent += `\n## ${functionName}\n`;
        } else if (line.startsWith("it('")) {
          const start = "it('".length;
          const end = line.indexOf("',");

          const testName = line.substring(start, end);
          // console.log(`\n## ${testName}\n`);
          markdownContent += `\n## ${testName}\n`;
        } else if (line.startsWith("/// ")) {
          const start = "/// ".length;

          const comment = line.substring(start);
          // console.log(comment);
          markdownContent += `- ${comment}\n`;
        }
      }

      resolve(markdownContent);
    });
  });
};

const generateMarkdown = async () => {
  const markdownContent = await parseFile("./test/StableAsset.ts");
  fs.writeFileSync("./test/docs/StableAsset.md", markdownContent, {
    encoding: "utf-8",
  });
  const markdownContent2 = await parseFile("./test/TapETH.ts");
  fs.writeFileSync("./test/docs/TapETH.md", markdownContent2, {
    encoding: "utf-8",
  });
  const markdownContent3 = await parseFile("./test/WTapETH.ts");
  fs.writeFileSync("./test/docs/WTapETH.md", markdownContent3, {
    encoding: "utf-8",
  });
  const markdownContent4 = await parseFile("./test/StableAssetApplication.ts");
  fs.writeFileSync("./test/docs/StableAssetApplication.md", markdownContent4, {
    encoding: "utf-8",
  });
};
generateMarkdown();
